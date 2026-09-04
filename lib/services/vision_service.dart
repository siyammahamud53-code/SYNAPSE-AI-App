import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

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
  
  FaceDetector? _faceDetector;
  ObjectDetector? _objectDetector;
  TextRecognizer? _textRecognizer;
  PoseDetector? _poseDetector;
  
  Map<String, dynamic> _lastAnalysis = {};
  final List<Map<String, dynamic>> _detectionHistory = [];
  
  bool get isProcessing => _isProcessing;
  bool get isCameraAvailable => _isCameraAvailable;
  Map<String, dynamic> get lastAnalysis => _lastAnalysis;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      Logger.info('Initializing VisionService...');
      await _initializeCamera();
      await _initializeDetectors();
      
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
        options: ObjectDetectorOptions(
          mode: DetectionMode.stream,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );
      
      _textRecognizer = GoogleMlKit.vision.textRecognizer();
      
      _poseDetector = GoogleMlKit.vision.poseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.single,
        ),
      );
      
      Logger.info('ML Kit detectors initialized');
    } catch (e) {
      Logger.error('Detectors initialization failed: $e');
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
    final landmarksJson = <String, dynamic>{};
    
    pose.landmarks.forEach((type, landmark) {
      landmarksJson[type.name] = {
        'x': landmark.x,
        'y': landmark.y,
        'z': landmark.z,
        'likelihood': landmark.likelihood,
      };
    });
    
    return {
      'landmarks': landmarksJson,
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
    super.dispose();
  }
}
