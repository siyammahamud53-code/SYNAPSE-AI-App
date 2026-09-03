import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:tflite_flutter/tflite_flutter.dart'; // Fixed: Official tflite_flutter
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

// Local Logger class added to resolve getter errors
class Logger {
  static void info(String msg) => debugPrint('[INFO] $msg');
  static void warning(String msg) => debugPrint('[WARN] $msg');
  static void error(String msg, [dynamic stackTrace]) => debugPrint('[ERROR] $msg');
  static void debug(String msg) => debugPrint('[DEBUG] $msg');
}

class VisionService extends ChangeNotifier {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();
  
  final MethodChannel _nativeChannel = const MethodChannel('com.synapse.ai/native');
  
  bool _isInitialized = false;
  bool _isCameraAvailable = false;
  bool _isProcessing = false;
  
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  
  final ImagePicker _imagePicker = ImagePicker();
  
  // ML Kit detectors
  FaceDetector? _faceDetector;
  ObjectDetector? _objectDetector;
  TextRecognizer? _textRecognizer;
  PoseDetector? _poseDetector;
  
  // TFLite Interpreter
  Interpreter? _interpreter;
  Map<String, dynamic>? _modelConfig;
  
  // Analysis results
  Map<String, dynamic> _lastAnalysis = {};
  final List<Map<String, dynamic>> _detectionHistory = [];
  
  // Getters
  bool get isProcessing => _isProcessing;
  bool get isCameraAvailable => _isCameraAvailable;
  Map<String, dynamic> get lastAnalysis => _lastAnalysis;
  
  // Initialization
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      Logger.info('Initializing VisionService...');
      
      // Initialize camera
      await _initializeCamera();
      
      // Initialize ML Kit detectors
      await _initializeDetectors();
      
      // Initialize TFLite model
      await _initializeTFLite();
      
      _isInitialized = true;
      Logger.info('VisionService initialized successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('VisionService initialization failed: $e', stackTrace);
      rethrow;
    }
  }
  
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras != null && _cameras!.isNotEmpty) {
        final camera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
        
        _cameraController = CameraController(
          camera,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        
        await _cameraController!.initialize();
        _isCameraAvailable = true;
        
        Logger.info('Camera initialized: ${camera.name}');
      } else {
        Logger.warning('No cameras available');
      }
    } catch (e) {
      Logger.error('Camera initialization failed: $e');
      _isCameraAvailable = false;
    }
  }
  
  Future<void> _initializeDetectors() async {
    try {
      _faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          enableClassification: true,
          enableContours: true,
          enableLandmarks: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      
      _objectDetector = GoogleMlKit.vision.objectDetector(
        ObjectDetectorOptions(
          mode: ObjectDetectorMode.stream,
          multipleObjects: true,
          classifyObjects: true,
        ),
      );
      
      _textRecognizer = GoogleMlKit.vision.textRecognizer(
        TextRecognizerOptions(),
      );
      
      _poseDetector = GoogleMlKit.vision.poseDetector(
        PoseDetectorOptions(
          mode: PoseDetectorMode.accurate,
          enableClassification: true,
          enableLandmarks: true,
        ),
      );
      
      Logger.info('ML Kit detectors initialized');
    } catch (e) {
      Logger.error('Detectors initialization failed: $e');
    }
  }
  
  Future<void> _initializeTFLite() async {
    try {
      final modelPath = await _getModelPath('assets/models/vision_model.tflite');
      
      if (modelPath != null && await File(modelPath).exists()) {
        final options = InterpreterOptions()..threads = 4;
        
        _interpreter = await Interpreter.fromFile(
          File(modelPath),
          options: options,
        );
        
        final configPath = await _getModelPath('assets/models/vision_config.json');
        if (configPath != null) {
          final configFile = File(configPath);
          if (await configFile.exists()) {
            final configString = await configFile.readAsString();
            _modelConfig = jsonDecode(configString);
          }
        }
        
        Logger.info('TFLite model loaded');
      } else {
        Logger.warning('TFLite model not found');
      }
    } catch (e) {
      Logger.error('TFLite initialization failed: $e');
    }
  }
  
  Future<String?> _getModelPath(String assetPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${dir.path}/models');
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }
      
      final modelPath = '${modelDir.path}/${assetPath.split('/').last}';
      
      if (!await File(modelPath).exists()) {
        try {
          final data = await rootBundle.load(assetPath);
          final file = File(modelPath);
          await file.writeAsBytes(data.buffer.asUint8List());
        } catch (e) {
          Logger.warning('Failed to copy model: $e');
          return null;
        }
      }
      
      return modelPath;
    } catch (e) {
      Logger.error('Failed to get model path: $e');
      return null;
    }
  }
  
  Future<String?> captureImage() async {
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        Logger.warning('Camera not available, using image picker');
        return await _pickImageFromGallery();
      }
      
      final XFile? image = await _cameraController!.takePicture();
      if (image != null) {
        Logger.info('Image captured: ${image.path}');
        return image.path;
      }
      
      return null;
    } catch (e) {
      Logger.error('Image capture failed: $e');
      return null;
    }
  }
  
  Future<String?> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
      
      if (image != null) {
        Logger.info('Image picked: ${image.path}');
        return image.path;
      }
      
      return null;
    } catch (e) {
      Logger.error('Image pick failed: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>> processImage(String imagePath) async {
    _isProcessing = true;
    notifyListeners();
    
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found: $imagePath');
      }
      
      final inputImage = InputImage.fromFile(imageFile);
      final results = <String, dynamic>{};
      
      try {
        final faces = await _faceDetector?.processImage(inputImage) ?? [];
        results['faces'] = faces.map((face) => _faceToJson(face)).toList();
      } catch (e) {
        Logger.error('Face detection failed: $e');
        results['faces'] = [];
      }
      
      try {
        final objects = await _objectDetector?.processImage(inputImage) ?? [];
        results['objects'] = objects.map((obj) => _objectToJson(obj)).toList();
      } catch (e) {
        Logger.error('Object detection failed: $e');
        results['objects'] = [];
      }
      
      try {
        final text = await _textRecognizer?.processImage(inputImage);
        results['text'] = text?.text ?? '';
        results['textBlocks'] = text?.blocks.map((block) => _textBlockToJson(block)).toList() ?? [];
      } catch (e) {
        Logger.error('Text recognition failed: $e');
        results['text'] = '';
        results['textBlocks'] = [];
      }
      
      try {
        final poses = await _poseDetector?.processImage(inputImage) ?? [];
        results['poses'] = poses.map((pose) => _poseToJson(pose)).toList();
      } catch (e) {
        Logger.error('Pose detection failed: $e');
        results['poses'] = [];
      }
      
      try {
        final tfliteResults = await _runTFLiteInference(imagePath);
        results['tflite'] = tfliteResults;
      } catch (e) {
        Logger.error('TFLite inference failed: $e');
        results['tflite'] = {};
      }
      
      _lastAnalysis = results;
      _detectionHistory.add({
        'timestamp': DateTime.now().toIso8601String(),
        'results': results,
      });
      
      if (_detectionHistory.length > 100) {
        _detectionHistory.removeAt(0);
      }
      
      Logger.info('Image processed: ${results.keys.join(', ')}');
      return results;
    } catch (e, stackTrace) {
      Logger.error('Image processing failed: $e', stackTrace);
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
  
  Future<Map<String, dynamic>> _runTFLiteInference(String imagePath) async {
    if (_interpreter == null) {
      return {'error': 'TFLite model not loaded'};
    }
    
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        return {'error': 'Failed to decode image'};
      }
      
      final inputSize = _modelConfig?['inputSize'] ?? 224;
      final resized = img.copyResize(image, width: inputSize, height: inputSize);
      
      final pixels = Float32List(inputSize * inputSize * 3);
      int index = 0;
      for (var y = 0; y < inputSize; y++) {
        for (var x = 0; x < inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          pixels[index++] = (pixel.r / 255.0);
          pixels[index++] = (pixel.g / 255.0);
          pixels[index++] = (pixel.b / 255.0);
        }
      }
      
      final output = Float32List(_modelConfig?['outputSize'] ?? 1000);
      final inputTensor = [pixels.reshape([1, inputSize, inputSize, 3])];
      final outputTensor = [output.reshape([1, _modelConfig?['outputSize'] ?? 1000])];
      
      _interpreter!.run(inputTensor, outputTensor);
      
      final result = outputTensor[0] as Float32List;
      final maxVal = result.reduce((a, b) => a > b ? a : b);
      final maxIdx = result.indexOf(maxVal);
      
      String label = 'Unknown';
      final labels = _modelConfig?['labels'] as List?;
      if (labels != null && maxIdx < labels.length) {
        label = labels[maxIdx];
      }
      
      return {
        'prediction': label,
        'confidence': maxVal,
        'index': maxIdx,
      };
    } catch (e) {
      Logger.error('TFLite inference failed: $e');
      return {'error': e.toString()};
    }
  }
  
  Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    final results = await processImage(imagePath);
    return {
      'analysis': results,
      'timestamp': DateTime.now().toIso8601String(),
      'imagePath': imagePath,
    };
  }
  
  Future<List<Map<String, dynamic>>> detectObjects(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found: $imagePath');
      }
      
      final inputImage = InputImage.fromFile(imageFile);
      final objects = await _objectDetector?.processImage(inputImage) ?? [];
      
      return objects.map((obj) => _objectToJson(obj)).toList();
    } catch (e) {
      Logger.error('Object detection failed: $e');
      return [];
    }
  }
  
  Map<String, dynamic> _faceToJson(Face face) {
    return {
      'boundingBox': {
        'left': face.boundingBox.left,
        'top': face.boundingBox.top,
        'right': face.boundingBox.right,
        'bottom': face.boundingBox.bottom,
      },
      'trackingId': face.trackingId,
      'smilingProbability': face.smilingProbability,
      'leftEyeOpenProbability': face.leftEyeOpenProbability,
      'rightEyeOpenProbability': face.rightEyeOpenProbability,
    };
  }
  
  Map<String, dynamic> _objectToJson(DetectedObject obj) {
    return {
      'label': obj.labels.firstOrNull?.text ?? 'Unknown',
      'confidence': obj.labels.firstOrNull?.confidence ?? 0.0,
      'boundingBox': {
        'left': obj.boundingBox.left,
        'top': obj.boundingBox.top,
        'right': obj.boundingBox.right,
        'bottom': obj.boundingBox.bottom,
      },
    };
  }
  
  Map<String, dynamic> _textBlockToJson(TextBlock block) {
    return {
      'text': block.text,
      'boundingBox': {
        'left': block.boundingBox.left,
        'top': block.boundingBox.top,
        'right': block.boundingBox.right,
        'bottom': block.boundingBox.bottom,
      },
      'lines': block.lines.map((line) => line.text).toList(),
    };
  }
  
  Map<String, dynamic> _poseToJson(Pose pose) {
    return {
      'landmarks': pose.landmarks.map((landmark) => {
        'type': landmark.type.toString(),
        'position': {
          'x': landmark.position.x,
          'y': landmark.position.y,
        },
        'isVisible': landmark.isVisible,
      }).toList(),
    };
  }
  
  Future<String?> takeScreenshot() async {
    try {
      final result = await _nativeChannel.invokeMethod('takeScreenshot');
      if (result != null) {
        Logger.info('Screenshot taken');
        return result.toString();
      }
      return null;
    } catch (e) {
      Logger.error('Screenshot failed: $e');
      return null;
    }
  }
  
  List<Map<String, dynamic>> getDetectionHistory() {
    return _detectionHistory;
  }
  
  void clearHistory() {
    _detectionHistory.clear();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
    _objectDetector?.close();
    _textRecognizer?.close();
    _poseDetector?.close();
    _interpreter?.close();
    super.dispose();
  }
}
