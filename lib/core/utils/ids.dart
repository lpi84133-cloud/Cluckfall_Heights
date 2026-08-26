import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Identifier for a new record.
///
/// Random rather than sequential: ids travel through export files, and a
/// collision after an import would silently overwrite someone's work.
String newId() => _uuid.v4();
