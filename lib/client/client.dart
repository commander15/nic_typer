import 'package:dio/dio.dart';
import 'package:mrz_parser/mrz_parser.dart';

class Client {
  final String _url;
  final Dio dio = Dio();

  Client({required String url}) : _url = url;

  Future<bool> postMrz(MRZResult mrz) async {
    print("Posting mrz: ${mrz.documentNumber}");
    final response = await dio.post(
      _url,
      data: {
        "documentNumber": mrz.documentNumber,
        "personalNumber": mrz.personalNumber,
        "expiryDate": mrz.expiryDate.toIso8601String(),
        "birthDate": mrz.birthDate.toIso8601String(),
        "sex": mrz.sex.toString(),
        "nationalityCountryCode": mrz.nationalityCountryCode,
        "countryCode": mrz.countryCode,
        "documentType": mrz.documentType,
        "surnames": mrz.surnames,
        "givenNames": mrz.givenNames,
      },
      options: Options(headers: {"Content-Type": "application/json"}),
    );

    return response.statusCode == 200;
  }
}
