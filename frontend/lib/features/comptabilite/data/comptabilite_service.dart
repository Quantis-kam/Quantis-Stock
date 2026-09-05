import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/file_download_helper.dart';

class EcritureGrandLivre {
  final String date;
  final String typeFlux;
  final String referencePiece;
  final String tiersOuCategorie;
  final String libelle;
  final double debit;
  final double credit;
  final double soldeProgressif;

  EcritureGrandLivre({
    required this.date,
    required this.typeFlux,
    required this.referencePiece,
    required this.tiersOuCategorie,
    required this.libelle,
    required this.debit,
    required this.credit,
    required this.soldeProgressif,
  });

  factory EcritureGrandLivre.fromJson(Map<String, dynamic> json) {
    return EcritureGrandLivre(
      date: json['date']?.toString() ?? '',
      typeFlux: json['typeFlux']?.toString() ?? '',
      referencePiece: json['referencePiece']?.toString() ?? '',
      tiersOuCategorie: json['tiersOuCategorie']?.toString() ?? '',
      libelle: json['libelle']?.toString() ?? '',
      debit: (json['debit'] as num? ?? 0).toDouble(),
      credit: (json['credit'] as num? ?? 0).toDouble(),
      soldeProgressif: (json['soldeProgressif'] as num? ?? 0).toDouble(),
    );
  }
}

class ClotureSynthese {
  final String periode;
  final String libelle;
  final String dateDebut;
  final String dateFin;
  final double chiffreAffairesTtc;
  final double chiffreAffairesHt;
  final double totalTvaCollectee;
  final double totalAchatsHt;
  final double totalDepensesCaisse;
  final double totalEntreesCaisse;
  final double margeBruteEstimee;
  final double valeurStockFinPeriode;
  final double totalCreancesClients;
  final double totalDettesFournisseurs;
  final double soldeCaisseFinal;
  final int nombreVentes;
  final int nombreAchats;
  final bool dejaCloturee;

  ClotureSynthese({
    required this.periode,
    required this.libelle,
    required this.dateDebut,
    required this.dateFin,
    required this.chiffreAffairesTtc,
    required this.chiffreAffairesHt,
    required this.totalTvaCollectee,
    required this.totalAchatsHt,
    required this.totalDepensesCaisse,
    required this.totalEntreesCaisse,
    required this.margeBruteEstimee,
    required this.valeurStockFinPeriode,
    required this.totalCreancesClients,
    required this.totalDettesFournisseurs,
    required this.soldeCaisseFinal,
    required this.nombreVentes,
    required this.nombreAchats,
    required this.dejaCloturee,
  });

  factory ClotureSynthese.fromJson(Map<String, dynamic> json) {
    return ClotureSynthese(
      periode: json['periode']?.toString() ?? '',
      libelle: json['libelle']?.toString() ?? '',
      dateDebut: json['dateDebut']?.toString() ?? '',
      dateFin: json['dateFin']?.toString() ?? '',
      chiffreAffairesTtc: (json['chiffreAffairesTtc'] as num? ?? 0).toDouble(),
      chiffreAffairesHt: (json['chiffreAffairesHt'] as num? ?? 0).toDouble(),
      totalTvaCollectee: (json['totalTvaCollectee'] as num? ?? 0).toDouble(),
      totalAchatsHt: (json['totalAchatsHt'] as num? ?? 0).toDouble(),
      totalDepensesCaisse: (json['totalDepensesCaisse'] as num? ?? 0).toDouble(),
      totalEntreesCaisse: (json['totalEntreesCaisse'] as num? ?? 0).toDouble(),
      margeBruteEstimee: (json['margeBruteEstimee'] as num? ?? 0).toDouble(),
      valeurStockFinPeriode: (json['valeurStockFinPeriode'] as num? ?? 0).toDouble(),
      totalCreancesClients: (json['totalCreancesClients'] as num? ?? 0).toDouble(),
      totalDettesFournisseurs: (json['totalDettesFournisseurs'] as num? ?? 0).toDouble(),
      soldeCaisseFinal: (json['soldeCaisseFinal'] as num? ?? 0).toDouble(),
      nombreVentes: json['nombreVentes'] as int? ?? 0,
      nombreAchats: json['nombreAchats'] as int? ?? 0,
      dejaCloturee: json['dejaCloturee'] as bool? ?? false,
    );
  }
}

class ClotureComptableModel {
  final int id;
  final String periode;
  final String libelle;
  final String dateDebut;
  final String dateFin;
  final String dateCloture;
  final String clotureParNom;
  final double chiffreAffairesTtc;
  final double margeBruteEstimee;
  final double soldeCaisseFinal;
  final double valeurStockFinPeriode;
  final String statut;
  final String? notes;

  ClotureComptableModel({
    required this.id,
    required this.periode,
    required this.libelle,
    required this.dateDebut,
    required this.dateFin,
    required this.dateCloture,
    required this.clotureParNom,
    required this.chiffreAffairesTtc,
    required this.margeBruteEstimee,
    required this.soldeCaisseFinal,
    required this.valeurStockFinPeriode,
    required this.statut,
    this.notes,
  });

  factory ClotureComptableModel.fromJson(Map<String, dynamic> json) {
    return ClotureComptableModel(
      id: json['id'] as int? ?? 0,
      periode: json['periode']?.toString() ?? '',
      libelle: json['libelle']?.toString() ?? '',
      dateDebut: json['dateDebut']?.toString() ?? '',
      dateFin: json['dateFin']?.toString() ?? '',
      dateCloture: json['dateCloture']?.toString() ?? '',
      clotureParNom: json['cloturePar']?['nomComplet']?.toString() ?? 'Administrateur',
      chiffreAffairesTtc: (json['chiffreAffairesTtc'] as num? ?? 0).toDouble(),
      margeBruteEstimee: (json['margeBruteEstimee'] as num? ?? 0).toDouble(),
      soldeCaisseFinal: (json['soldeCaisseFinal'] as num? ?? 0).toDouble(),
      valeurStockFinPeriode: (json['valeurStockFinPeriode'] as num? ?? 0).toDouble(),
      statut: json['statut']?.toString() ?? 'VERROUILLE',
      notes: json['notes']?.toString(),
    );
  }
}

class ComptabiliteService {
  final Dio _dio = ApiClient.instance;

  Future<List<EcritureGrandLivre>> getGrandLivre({
    required DateTime debut,
    required DateTime fin,
  }) async {
    final res = await _dio.get(
      '/accounting/grand-livre',
      queryParameters: {
        'debut': debut.toIso8601String().substring(0, 10),
        'fin': fin.toIso8601String().substring(0, 10),
      },
    );
    final list = res.data['data'] as List? ?? [];
    return list.map((e) => EcritureGrandLivre.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ClotureSynthese> simulerCloture({
    required DateTime debut,
    required DateTime fin,
    required String periode,
  }) async {
    final res = await _dio.get(
      '/accounting/clotures/simuler',
      queryParameters: {
        'debut': debut.toIso8601String().substring(0, 10),
        'fin': fin.toIso8601String().substring(0, 10),
        'periode': periode,
      },
    );
    return ClotureSynthese.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<ClotureComptableModel> validerCloture({
    required String periode,
    String? libelle,
    required DateTime debut,
    required DateTime fin,
    String? notes,
  }) async {
    final res = await _dio.post(
      '/accounting/clotures',
      data: {
        'periode': periode,
        'libelle': libelle ?? 'Arrêté Mensuel $periode',
        'dateDebut': debut.toIso8601String().substring(0, 10),
        'dateFin': fin.toIso8601String().substring(0, 10),
        'notes': notes ?? '',
      },
    );
    return ClotureComptableModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<List<ClotureComptableModel>> getHistoriqueClotures() async {
    final res = await _dio.get('/accounting/clotures');
    final list = res.data['data'] as List? ?? [];
    return list.map((e) => ClotureComptableModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> exportGrandLivreCsv({
    required DateTime debut,
    required DateTime fin,
  }) async {
    final debutStr = debut.toIso8601String().substring(0, 10);
    final finStr = fin.toIso8601String().substring(0, 10);
    final res = await _dio.get(
      '/accounting/grand-livre/export',
      queryParameters: {'debut': debutStr, 'fin': finStr},
      options: Options(responseType: ResponseType.bytes),
    );
    FileDownloadHelper.download(
      res.data as List<int>,
      'grand_livre_${debutStr}_$finStr.csv',
      mimeType: 'text/csv;charset=utf-8',
    );
  }

  Future<Map<String, dynamic>> seedDemoData() async {
    final res = await _dio.post('/accounting/seed-demo');
    return res.data['data'] as Map<String, dynamic>? ?? {};
  }
}
