import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

/// Modèle Mouvement de stock.
class MouvementModel {
  final int? id;
  final String type;
  final String? motif;
  final String? produitNom;
  final String? depotSourceNom;
  final String? depotDestNom;
  final double quantite;
  final String? reference;
  final String? commentaire;
  final String? createdAt;

  MouvementModel({
    this.id,
    required this.type,
    this.motif,
    this.produitNom,
    this.depotSourceNom,
    this.depotDestNom,
    this.quantite = 0,
    this.reference,
    this.commentaire,
    this.createdAt,
  });

  factory MouvementModel.fromJson(Map<String, dynamic> json) {
    return MouvementModel(
      id: json['id'] as int?,
      type: json['type'] as String? ?? '',
      motif: json['motif'] as String?,
      produitNom: (json['produit'] as Map<String, dynamic>?)?['nom'] as String?,
      depotSourceNom: (json['depotSource'] as Map<String, dynamic>?)?['nom'] as String?,
      depotDestNom: (json['depotDest'] as Map<String, dynamic>?)?['nom'] as String?,
      quantite: (json['quantite'] as num?)?.toDouble() ?? 0,
      reference: json['reference'] as String?,
      commentaire: json['commentaire'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  String get typeLabel => switch (type) {
        'ENTREE' => 'Entrée',
        'SORTIE' => 'Sortie',
        'TRANSFERT' => 'Transfert',
        'AJUSTEMENT' => 'Ajustement',
        _ => type,
      };

  String get motifLabel => switch (motif) {
        'ACHAT' => 'Achat',
        'VENTE' => 'Vente',
        'RETOUR_CLIENT' => 'Retour client',
        'RETOUR_FOURNISSEUR' => 'Retour fournisseur',
        'AJUSTEMENT_INVENTAIRE' => 'Inventaire',
        'PERTE' => 'Perte',
        'TRANSFERT_DEPOT' => 'Transfert',
        _ => motif ?? '',
      };
}

/// Modèle Stock courant.
class StockCourantModel {
  final int? id;
  final String? produitNom;
  final String? depotNom;
  final double quantite;
  final int seuilAlerte;

  StockCourantModel({this.id, this.produitNom, this.depotNom, this.quantite = 0, this.seuilAlerte = 10});

  factory StockCourantModel.fromJson(Map<String, dynamic> json) {
    return StockCourantModel(
      id: json['id'] as int?,
      produitNom: (json['produit'] as Map<String, dynamic>?)?['nom'] as String?,
      depotNom: (json['depot'] as Map<String, dynamic>?)?['nom'] as String?,
      quantite: (json['quantite'] as num?)?.toDouble() ?? 0,
      seuilAlerte: (json['produit'] as Map<String, dynamic>?)?['seuilAlerte'] as int? ?? 10,
    );
  }

  bool get isAlerte => quantite <= seuilAlerte;
  bool get isRupture => quantite <= 0;
}

/// Service API Stock.
class StockApiService {
  final Dio _dio = ApiClient.instance;

  Future<List<MouvementModel>> getMouvements({int page = 0, int size = 50}) async {
    final response = await _dio.get('/stock/movements', queryParameters: {'page': page, 'size': size});
    final data = response.data['data']['content'] as List;
    return data.map((e) => MouvementModel.fromJson(e)).toList();
  }

  Future<List<StockCourantModel>> getAlertes() async {
    final response = await _dio.get('/stock/alerts');
    final data = response.data['data'] as List;
    return data.map((e) => StockCourantModel.fromJson(e)).toList();
  }
}
