/// Modèle Commande Fournisseur côté Flutter.
class CommandeModel {
  final int? id;
  final String numero;
  final String statut;
  final String? fournisseurNom;
  final int? fournisseurId;
  final String? depotNom;
  final int? depotId;
  final String? dateCommande;
  final String? dateLivraisonPrevue;
  final double totalHt;
  final String? notes;
  final List<LigneCommandeModel> lignes;

  CommandeModel({
    this.id,
    required this.numero,
    this.statut = 'BROUILLON',
    this.fournisseurNom,
    this.fournisseurId,
    this.depotNom,
    this.depotId,
    this.dateCommande,
    this.dateLivraisonPrevue,
    this.totalHt = 0,
    this.notes,
    this.lignes = const [],
  });

  factory CommandeModel.fromJson(Map<String, dynamic> json) {
    return CommandeModel(
      id: json['id'] as int?,
      numero: json['numero'] as String? ?? '',
      statut: json['statut'] as String? ?? 'BROUILLON',
      fournisseurNom: (json['fournisseur'] as Map<String, dynamic>?)?['nom'] as String?,
      fournisseurId: (json['fournisseur'] as Map<String, dynamic>?)?['id'] as int?,
      depotNom: (json['depot'] as Map<String, dynamic>?)?['nom'] as String?,
      depotId: (json['depot'] as Map<String, dynamic>?)?['id'] as int?,
      dateCommande: json['dateCommande'] as String?,
      dateLivraisonPrevue: json['dateLivraisonPrevue'] as String?,
      totalHt: (json['totalHt'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      lignes: (json['lignes'] as List<dynamic>?)
              ?.map((e) => LigneCommandeModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String get statutLabel => switch (statut) {
        'BROUILLON' => 'Brouillon',
        'EN_COURS' => 'En cours',
        'RECUE_PARTIELLE' => 'Réception partielle',
        'RECUE' => 'Reçue',
        'ANNULEE' => 'Annulée',
        _ => statut,
      };

  bool get canValidate => statut == 'BROUILLON';
  bool get canReceive => statut == 'EN_COURS' || statut == 'RECUE_PARTIELLE';
  bool get canCancel => statut != 'RECUE' && statut != 'ANNULEE';
}

class LigneCommandeModel {
  final int? id;
  final String? produitNom;
  final int? produitId;
  final double quantiteCommandee;
  final double quantiteRecue;
  final double prixUnitaire;

  LigneCommandeModel({
    this.id,
    this.produitNom,
    this.produitId,
    this.quantiteCommandee = 0,
    this.quantiteRecue = 0,
    this.prixUnitaire = 0,
  });

  factory LigneCommandeModel.fromJson(Map<String, dynamic> json) {
    return LigneCommandeModel(
      id: json['id'] as int?,
      produitNom: (json['produit'] as Map<String, dynamic>?)?['nom'] as String?,
      produitId: (json['produit'] as Map<String, dynamic>?)?['id'] as int?,
      quantiteCommandee: (json['quantiteCommandee'] as num?)?.toDouble() ?? 0,
      quantiteRecue: (json['quantiteRecue'] as num?)?.toDouble() ?? 0,
      prixUnitaire: (json['prixUnitaire'] as num?)?.toDouble() ?? 0,
    );
  }

  double get quantiteRestante => quantiteCommandee - quantiteRecue;
  double get montantTotal => prixUnitaire * quantiteCommandee;
  bool get isComplete => quantiteRecue >= quantiteCommandee;
}
