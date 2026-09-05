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

  String get dateHeureFormatted {
    if (createdAt == null || createdAt!.isEmpty) return '-';
    try {
      final dt = DateTime.parse(createdAt!).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y à $h:$min';
    } catch (_) {
      return createdAt!.replaceAll('T', ' ').substring(0, createdAt!.length > 16 ? 16 : createdAt!.length);
    }
  }

  String get dateFormatted {
    if (createdAt == null || createdAt!.isEmpty) return '-';
    try {
      final dt = DateTime.parse(createdAt!).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d/$m/${dt.year}';
    } catch (_) {
      return createdAt!;
    }
  }

  String get heureFormatted {
    if (createdAt == null || createdAt!.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt!).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$h:$min';
    } catch (_) {
      return '';
    }
  }
}

/// Modèle Stock courant.
class StockCourantModel {
  final int? id;
  final int produitId;
  final String? produitNom;
  final int? varianteId;
  final String? varianteNom;
  final String? depotNom;
  final double quantite;
  final int seuilAlerte;

  StockCourantModel({
    this.id,
    required this.produitId,
    this.produitNom,
    this.varianteId,
    this.varianteNom,
    this.depotNom,
    this.quantite = 0,
    this.seuilAlerte = 10,
  });

  factory StockCourantModel.fromJson(Map<String, dynamic> json) {
    final produit = json['produit'] as Map<String, dynamic>?;
    final variante = json['variante'] as Map<String, dynamic>?;
    return StockCourantModel(
      id: json['id'] as int?,
      produitId: produit?['id'] as int? ?? 0,
      produitNom: produit?['nom'] as String?,
      varianteId: variante?['id'] as int?,
      varianteNom: (variante != null)
          ? '${variante['attribut']} : ${variante['valeur']}'
          : null,
      depotNom: (json['depot'] as Map<String, dynamic>?)?['nom'] as String?,
      quantite: (json['quantite'] as num?)?.toDouble() ?? 0,
      seuilAlerte: produit?['seuilAlerte'] as int? ?? 10,
    );
  }

  bool get isAlerte => quantite <= seuilAlerte;
  bool get isRupture => quantite <= 0;
}

class DepotModel {
  final int id;
  final String nom;
  final String? adresse;
  final String? telephone;

  DepotModel({required this.id, required this.nom, this.adresse, this.telephone});

  factory DepotModel.fromJson(Map<String, dynamic> json) {
    return DepotModel(
      id: json['id'] as int,
      nom: json['nom'] as String,
      adresse: json['adresse'] as String?,
      telephone: json['telephone'] as String?,
    );
  }
}

/// Service API Stock.
class StockApiService {
  final Dio _dio = ApiClient.instance;

  Future<List<DepotModel>> getDepots() async {
    final response = await _dio.get('/stock/depots');
    final data = response.data['data'] as List;
    return data.map((e) => DepotModel.fromJson(e)).toList();
  }

  Future<List<MouvementModel>> getMouvements({int page = 0, int size = 50}) async {
    final response = await _dio.get('/stock/movements', queryParameters: {'page': page, 'size': size});
    final data = response.data['data']['content'] as List;
    return data.map((e) => MouvementModel.fromJson(e)).toList();
  }

  Future<List<MouvementModel>> getMouvementsFiltered({
    int? depotId,
    String? type,
    int? produitId,
    String? startDate,
    String? endDate,
    int page = 0,
    int size = 50,
  }) async {
    final Map<String, dynamic> params = {'page': page, 'size': size};
    if (depotId != null) params['depotId'] = depotId;
    if (type != null && type != 'ALL') params['type'] = type;
    if (produitId != null) params['produitId'] = produitId;
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;

    final response = await _dio.get('/stock/movements/filter', queryParameters: params);
    final data = response.data['data']['content'] as List;
    return data.map((e) => MouvementModel.fromJson(e)).toList();
  }

  Future<List<StockCourantModel>> getStockByDepot(int depotId) async {
    final response = await _dio.get('/stock/depot/$depotId');
    final data = response.data['data'] as List;
    return data.map((e) => StockCourantModel.fromJson(e)).toList();
  }

  Future<MouvementModel> enregistrerMouvement(Map<String, dynamic> data) async {
    final response = await _dio.post('/stock/movements', data: data);
    return MouvementModel.fromJson(response.data['data']);
  }

  Future<void> reconcilierStock(Map<String, dynamic> data) async {
    await _dio.post('/stock/reconcile', data: data);
  }

  Future<List<StockCourantModel>> getAlertes() async {
    final response = await _dio.get('/stock/alerts');
    final data = response.data['data'] as List;
    return data.map((e) => StockCourantModel.fromJson(e)).toList();
  }
}
