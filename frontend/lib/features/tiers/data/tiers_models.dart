/// Modèle Client côté Flutter.
class ClientModel {
  final int? id;
  final String nom;
  final String? telephone;
  final String? email;
  final String? adresse;
  final double soldeCredit;
  final String? notes;
  final bool actif;

  ClientModel({
    this.id,
    required this.nom,
    this.telephone,
    this.email,
    this.adresse,
    this.soldeCredit = 0,
    this.notes,
    this.actif = true,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as int?,
      nom: json['nom'] as String,
      telephone: json['telephone'] as String?,
      email: json['email'] as String?,
      adresse: json['adresse'] as String?,
      soldeCredit: (json['soldeCredit'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      actif: json['actif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'telephone': telephone,
      'email': email,
      'adresse': adresse,
      'soldeCredit': soldeCredit,
      'notes': notes,
      'actif': actif,
    };
  }

  ClientModel copyWith({
    int? id,
    String? nom,
    String? telephone,
    String? email,
    String? adresse,
    double? soldeCredit,
    String? notes,
    bool? actif,
  }) {
    return ClientModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      adresse: adresse ?? this.adresse,
      soldeCredit: soldeCredit ?? this.soldeCredit,
      notes: notes ?? this.notes,
      actif: actif ?? this.actif,
    );
  }
}

/// Modèle Fournisseur côté Flutter.
class FournisseurModel {
  final int? id;
  final String nom;
  final String? telephone;
  final String? email;
  final String? adresse;
  final double soldeDette;
  final String? notes;
  final bool actif;

  FournisseurModel({
    this.id,
    required this.nom,
    this.telephone,
    this.email,
    this.adresse,
    this.soldeDette = 0,
    this.notes,
    this.actif = true,
  });

  factory FournisseurModel.fromJson(Map<String, dynamic> json) {
    return FournisseurModel(
      id: json['id'] as int?,
      nom: json['nom'] as String,
      telephone: json['telephone'] as String?,
      email: json['email'] as String?,
      adresse: json['adresse'] as String?,
      soldeDette: (json['soldeDette'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      actif: json['actif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'telephone': telephone,
      'email': email,
      'adresse': adresse,
      'soldeDette': soldeDette,
      'notes': notes,
      'actif': actif,
    };
  }

  FournisseurModel copyWith({
    int? id,
    String? nom,
    String? telephone,
    String? email,
    String? adresse,
    double? soldeDette,
    String? notes,
    bool? actif,
  }) {
    return FournisseurModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      adresse: adresse ?? this.adresse,
      soldeDette: soldeDette ?? this.soldeDette,
      notes: notes ?? this.notes,
      actif: actif ?? this.actif,
    );
  }
}
