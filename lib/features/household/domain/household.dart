/// Casa configurada en un dispositivo: agrupa los usuarios de un mismo hogar
/// en la instancia Jellyfin. La selección de usuarios solo muestra los de aquí.
class Household {
  const Household({
    required this.name,
    required this.userIds,
    this.serverId,
    this.pinHash,
    this.masterPinHash,
  });

  final String name;
  final List<String> userIds;

  /// Id del servidor Jellyfin al que pertenece esta casa. Sirve para invalidar
  /// la casa si el dispositivo cambia de servidor.
  final String? serverId;

  /// Hash SHA-256 del PIN que protege la gestión de la casa.
  final String? pinHash;

  /// Hash SHA-256 del PIN maestro de recuperación.
  final String? masterPinHash;

  /// Indica si la casa está vinculada al servidor [id].
  bool matchesServer(String? id) =>
      serverId != null && id != null && serverId == id;

  Household copyWith({
    String? name,
    List<String>? userIds,
    String? serverId,
    String? pinHash,
    String? masterPinHash,
    bool clearPin = false,
  }) {
    return Household(
      name: name ?? this.name,
      userIds: userIds ?? this.userIds,
      serverId: serverId ?? this.serverId,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
      masterPinHash: masterPinHash ?? this.masterPinHash,
    );
  }

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      name: json['name'] as String? ?? '',
      userIds: (json['userIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      serverId: json['serverId'] as String?,
      pinHash: json['pinHash'] as String?,
      masterPinHash: json['masterPinHash'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'userIds': userIds,
        if (serverId != null) 'serverId': serverId,
        if (pinHash != null) 'pinHash': pinHash,
        if (masterPinHash != null) 'masterPinHash': masterPinHash,
      };
}
