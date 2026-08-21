library;

// Casa configurada en un dispositivo: agrupa los usuarios de un mismo hogar
// en la instancia Jellyfin. Ya no expone la lista pública del servidor;
// cada miembro se agrega validando usuario+contraseña.

class HouseholdMember {
  const HouseholdMember({
    required this.id,
    required this.name,
    this.primaryImageTag,
  });

  final String id;
  final String name;
  final String? primaryImageTag;

  HouseholdMember copyWith({String? id, String? name, String? primaryImageTag}) {
    return HouseholdMember(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryImageTag: primaryImageTag ?? this.primaryImageTag,
    );
  }

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      primaryImageTag: json['primaryImageTag'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (primaryImageTag != null) 'primaryImageTag': primaryImageTag,
      };
}

class Household {
  const Household({
    required this.name,
    required this.members,
    this.serverId,
    this.pinHash,
    this.masterPinHash,
  });

  final String name;
  final List<HouseholdMember> members;

  /// Compatibilidad: lista de ids derivada de [members].
  List<String> get userIds => members.map((m) => m.id).toList();

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
    List<HouseholdMember>? members,
    List<String>? userIds,
    String? serverId,
    String? pinHash,
    String? masterPinHash,
    bool clearPin = false,
  }) {
    return Household(
      name: name ?? this.name,
      members: members ??
          (userIds != null
              ? userIds
                  .map((id) => HouseholdMember(id: id, name: id))
                  .toList()
              : this.members),
      serverId: serverId ?? this.serverId,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
      masterPinHash: masterPinHash ?? this.masterPinHash,
    );
  }

  factory Household.fromJson(Map<String, dynamic> json) {
    // Formato nuevo: members
    final rawMembers = json['members'] as List<dynamic>?;
    if (rawMembers != null) {
      return Household(
        name: json['name'] as String? ?? '',
        members: rawMembers
            .map((e) => HouseholdMember.fromJson(e as Map<String, dynamic>))
            .toList(),
        serverId: json['serverId'] as String?,
        pinHash: json['pinHash'] as String?,
        masterPinHash: json['masterPinHash'] as String?,
      );
    }
    // Migración desde formato antiguo: userIds
    final oldIds = (json['userIds'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    return Household(
      name: json['name'] as String? ?? '',
      members: oldIds
          .map((id) => HouseholdMember(id: id, name: id))
          .toList(),
      serverId: json['serverId'] as String?,
      pinHash: json['pinHash'] as String?,
      masterPinHash: json['masterPinHash'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
        if (serverId != null) 'serverId': serverId,
        if (pinHash != null) 'pinHash': pinHash,
        if (masterPinHash != null) 'masterPinHash': masterPinHash,
      };
}
