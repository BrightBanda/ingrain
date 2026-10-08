/// Where the Flashcards screen gets Anki import from.
///
/// Reading a deck needs native SQLite (`dart:ffi`), which browsers do not
/// have; even importing that code stops the web build from compiling. So web
/// builds get a stand-in that explains where to import instead, and only
/// native builds ever see the real reader.
library;

export 'anki_import_unsupported.dart'
    if (dart.library.ffi) 'anki_import_dialog.dart';
