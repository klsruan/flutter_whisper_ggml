import 'package:flutter/foundation.dart';

/// Metadata for a downloadable whisper.cpp GGML model.
@immutable
final class WhisperModel {
  const WhisperModel({
    required this.id,
    required this.sizeBytes,
    required this.sha256,
    this.baseUrl = WhisperModels.defaultBaseUrl,
  });

  /// Model identifier used by the official whisper.cpp download scripts.
  final String id;

  /// Exact size of the current official model file.
  final int sizeBytes;

  /// SHA-256 digest published by the model repository.
  final String sha256;

  /// Repository directory containing [fileName].
  final String baseUrl;

  String get fileName => 'ggml-$id.bin';

  Uri get downloadUri => Uri.parse('$baseUrl/$fileName');

  bool get isEnglishOnly => id.contains('.en');

  bool get isQuantized => id.contains(RegExp(r'-q\d'));

  bool get supportsTinyDiarize => id.endsWith('-tdrz');

  String get sizeLabel {
    const gibibyte = 1024 * 1024 * 1024;
    const mebibyte = 1024 * 1024;
    if (sizeBytes >= gibibyte) {
      return '${(sizeBytes / gibibyte).toStringAsFixed(2)} GiB';
    }
    return '${(sizeBytes / mebibyte).toStringAsFixed(0)} MiB';
  }

  @override
  String toString() => 'WhisperModel($id, $sizeLabel)';
}

/// Models offered by the official whisper.cpp v1.9.2 download scripts.
abstract final class WhisperModels {
  static const defaultBaseUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';
  static const tinyDiarizeBaseUrl =
      'https://huggingface.co/akashmjn/tinydiarize-whisper.cpp/resolve/main';

  static const tiny = WhisperModel(
    id: 'tiny',
    sizeBytes: 77691713,
    sha256: 'be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21',
  );
  static const tinyQ5_1 = WhisperModel(
    id: 'tiny-q5_1',
    sizeBytes: 32152673,
    sha256: '818710568da3ca15689e31a743197b520007872ff9576237bda97bd1b469c3d7',
  );
  static const tinyQ8_0 = WhisperModel(
    id: 'tiny-q8_0',
    sizeBytes: 43537433,
    sha256: 'c2085835d3f50733e2ff6e4b41ae8a2b8d8110461e18821b09a15c40c42d1cca',
  );
  static const tinyEn = WhisperModel(
    id: 'tiny.en',
    sizeBytes: 77704715,
    sha256: '921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f',
  );
  static const tinyEnQ5_1 = WhisperModel(
    id: 'tiny.en-q5_1',
    sizeBytes: 32166155,
    sha256: 'c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b',
  );
  static const tinyEnQ8_0 = WhisperModel(
    id: 'tiny.en-q8_0',
    sizeBytes: 43550795,
    sha256: '5bc2b3860aa151a4c6e7bb095e1fcce7cf12c7b020ca08dcec0c6d018bb7dd94',
  );

  static const base = WhisperModel(
    id: 'base',
    sizeBytes: 147951465,
    sha256: '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe',
  );
  static const baseQ5_1 = WhisperModel(
    id: 'base-q5_1',
    sizeBytes: 59707625,
    sha256: '422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898',
  );
  static const baseQ8_0 = WhisperModel(
    id: 'base-q8_0',
    sizeBytes: 81768585,
    sha256: 'c577b9a86e7e048a0b7eada054f4dd79a56bbfa911fbdacf900ac5b567cbb7d9',
  );
  static const baseEn = WhisperModel(
    id: 'base.en',
    sizeBytes: 147964211,
    sha256: 'a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002',
  );
  static const baseEnQ5_1 = WhisperModel(
    id: 'base.en-q5_1',
    sizeBytes: 59721011,
    sha256: '4baf70dd0d7c4247ba2b81fafd9c01005ac77c2f9ef064e00dcf195d0e2fdd2f',
  );
  static const baseEnQ8_0 = WhisperModel(
    id: 'base.en-q8_0',
    sizeBytes: 81781811,
    sha256: 'a4d4a0768075e13cfd7e19df3ae2dbc4a68d37d36a7dad45e8410c9a34f8c87e',
  );

  static const small = WhisperModel(
    id: 'small',
    sizeBytes: 487601967,
    sha256: '1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b',
  );
  static const smallQ5_1 = WhisperModel(
    id: 'small-q5_1',
    sizeBytes: 190085487,
    sha256: 'ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb',
  );
  static const smallQ8_0 = WhisperModel(
    id: 'small-q8_0',
    sizeBytes: 264464607,
    sha256: '49c8fb02b65e6049d5fa6c04f81f53b867b5ec9540406812c643f177317f779f',
  );
  static const smallEn = WhisperModel(
    id: 'small.en',
    sizeBytes: 487614201,
    sha256: 'c6138d6d58ecc8322097e0f987c32f1be8bb0a18532a3f88f734d1bbf9c41e5d',
  );
  static const smallEnQ5_1 = WhisperModel(
    id: 'small.en-q5_1',
    sizeBytes: 190098681,
    sha256: 'bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30',
  );
  static const smallEnQ8_0 = WhisperModel(
    id: 'small.en-q8_0',
    sizeBytes: 264477561,
    sha256: '67a179f608ea6114bd3fdb9060e762b588a3fb3bd00c4387971be4d177958067',
  );
  static const smallEnTinyDiarize = WhisperModel(
    id: 'small.en-tdrz',
    sizeBytes: 487614184,
    sha256: 'ceac3ec06d1d98ef71aec665283564631055fd6129b79d8e1be4f9cc33cc54b4',
    baseUrl: tinyDiarizeBaseUrl,
  );

  static const medium = WhisperModel(
    id: 'medium',
    sizeBytes: 1533763059,
    sha256: '6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208',
  );
  static const mediumQ5_0 = WhisperModel(
    id: 'medium-q5_0',
    sizeBytes: 539212467,
    sha256: '19fea4b380c3a618ec4723c3eef2eb785ffba0d0538cf43f8f235e7b3b34220f',
  );
  static const mediumQ8_0 = WhisperModel(
    id: 'medium-q8_0',
    sizeBytes: 823369779,
    sha256: '42a1ffcbe4167d224232443396968db4d02d4e8e87e213d3ee2e03095dea6502',
  );
  static const mediumEn = WhisperModel(
    id: 'medium.en',
    sizeBytes: 1533774781,
    sha256: 'cc37e93478338ec7700281a7ac30a10128929eb8f427dda2e865faa8f6da4356',
  );
  static const mediumEnQ5_0 = WhisperModel(
    id: 'medium.en-q5_0',
    sizeBytes: 539225533,
    sha256: '76733e26ad8fe1c7a5bf7531a9d41917b2adc0f20f2e4f5531688a8c6cd88eb0',
  );
  static const mediumEnQ8_0 = WhisperModel(
    id: 'medium.en-q8_0',
    sizeBytes: 823382461,
    sha256: '43fa2cd084de5a04399a896a9a7a786064e221365c01700cea4666005218f11c',
  );

  static const largeV1 = WhisperModel(
    id: 'large-v1',
    sizeBytes: 3094623691,
    sha256: '7d99f41a10525d0206bddadd86760181fa920438b6b33237e3118ff6c83bb53d',
  );
  static const largeV2 = WhisperModel(
    id: 'large-v2',
    sizeBytes: 3094623691,
    sha256: '9a423fe4d40c82774b6af34115b8b935f34152246eb19e80e376071d3f999487',
  );
  static const largeV2Q5_0 = WhisperModel(
    id: 'large-v2-q5_0',
    sizeBytes: 1080732091,
    sha256: '3a214837221e4530dbc1fe8d734f302af393eb30bd0ed046042ebf4baf70f6f2',
  );
  static const largeV2Q8_0 = WhisperModel(
    id: 'large-v2-q8_0',
    sizeBytes: 1656129691,
    sha256: 'fef54e6d898246a65c8285bfa83bd1807e27fadf54d5d4e81754c47634737e8c',
  );
  static const largeV3 = WhisperModel(
    id: 'large-v3',
    sizeBytes: 3095033483,
    sha256: '64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2',
  );
  static const largeV3Q5_0 = WhisperModel(
    id: 'large-v3-q5_0',
    sizeBytes: 1081140203,
    sha256: 'd75795ecff3f83b5faa89d1900604ad8c780abd5739fae406de19f23ecd98ad1',
  );
  static const largeV3Turbo = WhisperModel(
    id: 'large-v3-turbo',
    sizeBytes: 1624555275,
    sha256: '1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69',
  );
  static const largeV3TurboQ5_0 = WhisperModel(
    id: 'large-v3-turbo-q5_0',
    sizeBytes: 574041195,
    sha256: '394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2',
  );
  static const largeV3TurboQ8_0 = WhisperModel(
    id: 'large-v3-turbo-q8_0',
    sizeBytes: 874188075,
    sha256: '317eb69c11673c9de1e1f0d459b253999804ec71ac4c23c17ecf5fbe24e259a1',
  );

  static const values = <WhisperModel>[
    tiny,
    tinyQ5_1,
    tinyQ8_0,
    tinyEn,
    tinyEnQ5_1,
    tinyEnQ8_0,
    base,
    baseQ5_1,
    baseQ8_0,
    baseEn,
    baseEnQ5_1,
    baseEnQ8_0,
    small,
    smallQ5_1,
    smallQ8_0,
    smallEn,
    smallEnQ5_1,
    smallEnQ8_0,
    smallEnTinyDiarize,
    medium,
    mediumQ5_0,
    mediumQ8_0,
    mediumEn,
    mediumEnQ5_0,
    mediumEnQ8_0,
    largeV1,
    largeV2,
    largeV2Q5_0,
    largeV2Q8_0,
    largeV3,
    largeV3Q5_0,
    largeV3Turbo,
    largeV3TurboQ5_0,
    largeV3TurboQ8_0,
  ];

  static WhisperModel? byId(String id) {
    for (final model in values) {
      if (model.id == id) return model;
    }
    return null;
  }
}
