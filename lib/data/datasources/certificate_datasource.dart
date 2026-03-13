import 'package:trusttunnel/data/model/certificate.dart';

abstract class CertificateDataSource {
  Future<Certificate?> pickCertificate();
}
