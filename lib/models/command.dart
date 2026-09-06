enum CommandType {
  voice,
  vision,
  call,
  system,
  automation,
}

class Command {
  final String id;
  final CommandType type;
  final Map<String, dynamic> parameters;
  final String timestamp;

  Command({
    required this.id,
    required this.type,
    required this.parameters,
    required this.timestamp,
  });

  factory Command.fromJson(Map<String, dynamic> json) {
    return Command(
      id: json['id'] ?? '',
      type: CommandType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['type'] ?? 'voice'),
        orElse: () => CommandType.voice,
      ),
      parameters: json['parameters'] ?? json['payload'] ?? {},
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'parameters': parameters,
      'timestamp': timestamp,
    };
  }
}
