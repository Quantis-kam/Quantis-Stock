/// Modèle Document commercial côté Flutter.
class DocumentModel {
  final int? id;
  final String type;
  final String numero;
  final String statut;
  final String? clientNom;
  final String? clientTelephone;
  final int? clientId;
  final String? depotNom;
  final String? dateDocument;
  final String? dateEcheance;
  final double totalHt;
  final double totalTva;
  final double totalTtc;
  final String? notes;
  final List<LigneDocumentModel> lignes;
  final List<PaiementModel> paiements;

  DocumentModel({
    this.id,
    required this.type,
    this.numero = '',
    this.statut = 'BROUILLON',
    this.clientNom,
    this.clientTelephone,
    this.clientId,
    this.depotNom,
    this.dateDocument,
    this.dateEcheance,
    this.totalHt = 0,
    this.totalTva = 0,
    this.totalTtc = 0,
    this.notes,
    this.lignes = const [],
    this.paiements = const [],
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as int?,
      type: json['type'] as String? ?? '',
      numero: json['numero'] as String? ?? '',
      statut: json['statut'] as String? ?? 'BROUILLON',
      clientNom: (json['client'] as Map<String, dynamic>?)?['nom'] as String?,
      clientTelephone: (json['client'] as Map<String, dynamic>?)?['telephone'] as String?,
      clientId: (json['client'] as Map<String, dynamic>?)?['id'] as int?,
      depotNom: (json['depot'] as Map<String, dynamic>?)?['nom'] as String?,
      dateDocument: json['dateDocument'] as String?,
      dateEcheance: json['dateEcheance'] as String?,
      totalHt: (json['totalHt'] as num?)?.toDouble() ?? 0,
      totalTva: (json['totalTva'] as num?)?.toDouble() ?? 0,
      totalTtc: (json['totalTtc'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      lignes: (json['lignes'] as List?)
              ?.map((e) => LigneDocumentModel.fromJson(e))
              .toList() ?? [],
      paiements: (json['paiements'] as List?)
              ?.map((e) => PaiementModel.fromJson(e))
              .toList() ?? [],
    );
  }

  String get typeLabel => switch (type) {
        'DEVIS' => 'Devis',
        'COMMANDE_CLIENT' => 'Bon de Commande',
        'BON_LIVRAISON' => 'Bon de livraison',
        'FACTURE' => 'Facture',
        'AVOIR' => 'Avoir',
        _ => type,
      };

  String get statutLabel => switch (statut) {
        'BROUILLON' => 'Brouillon',
        'VALIDE' => 'Validé',
        'ANNULE' => 'Annulé',
        _ => statut,
      };

  double get montantPaye =>
      paiements.fold(0.0, (sum, p) => sum + p.montant);

  double get soldeRestant => totalTtc - montantPaye;

  bool get isPayeIntegral => soldeRestant <= 0;
  bool get canValidate => statut == 'BROUILLON';
  bool get canPay => statut == 'VALIDE' && !isPayeIntegral;
}

class LigneDocumentModel {
  final int? id;
  final String designation;
  final double quantite;
  final double prixUnitaire;
  final double tauxTva;
  final double montantHt;
  final double montantTva;
  final double montantTtc;

  LigneDocumentModel({
    this.id,
    this.designation = '',
    this.quantite = 0,
    this.prixUnitaire = 0,
    this.tauxTva = 18,
    this.montantHt = 0,
    this.montantTva = 0,
    this.montantTtc = 0,
  });

  factory LigneDocumentModel.fromJson(Map<String, dynamic> json) {
    return LigneDocumentModel(
      id: json['id'] as int?,
      designation: json['designation'] as String? ?? '',
      quantite: (json['quantite'] as num?)?.toDouble() ?? 0,
      prixUnitaire: (json['prixUnitaire'] as num?)?.toDouble() ?? 0,
      tauxTva: (json['tauxTva'] as num?)?.toDouble() ?? 18,
      montantHt: (json['montantHt'] as num?)?.toDouble() ?? 0,
      montantTva: (json['montantTva'] as num?)?.toDouble() ?? 0,
      montantTtc: (json['montantTtc'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PaiementModel {
  final int? id;
  final double montant;
  final String moyen;
  final String? datePaiement;
  final String? reference;

  PaiementModel({
    this.id,
    this.montant = 0,
    this.moyen = '',
    this.datePaiement,
    this.reference,
  });

  factory PaiementModel.fromJson(Map<String, dynamic> json) {
    return PaiementModel(
      id: json['id'] as int?,
      montant: (json['montant'] as num?)?.toDouble() ?? 0,
      moyen: json['moyen'] as String? ?? '',
      datePaiement: json['datePaiement'] as String?,
      reference: json['reference'] as String?,
    );
  }

  String get moyenLabel => switch (moyen) {
        'ESPECES' => 'Espèces',
        'CHEQUE' => 'Chèque',
        'VIREMENT' => 'Virement',
        'MOBILE_MONEY' => 'Mobile Money',
        'CARTE' => 'Carte',
        _ => moyen,
      };
}
