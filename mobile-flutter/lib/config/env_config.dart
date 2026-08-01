/// Compile-time configuration, supplied via `--dart-define` /
/// `--dart-define-from-file` - this project's Flutter convention (see
/// `flutter/SKILL.md` and the sibling `mudbase-showcase-social`/
/// `mudbase-showcase-ecommerce` ports), never a runtime `.env` file.
///
/// Every value below is public (a Mudbase project/collection/board id is not
/// a secret, same as the web app's `NEXT_PUBLIC_*` vars) - there is no
/// server-side credential anywhere in this app. Unlike the social port's
/// `EnvConfig` (which requires every id with no default, forcing explicit
/// configuration for a project *without* a fixed identity), this app targets
/// one specific, already-provisioned, real shared project - so every value
/// below defaults to that project's real ids, matching the reference web
/// app's own `.env.example` (which ships the real values pre-filled,
/// ready to run). `--dart-define` still overrides any of them if a
/// consumer of this repo points it at their own project.
class EnvConfig {
  const EnvConfig._();

  static const String mudbaseBaseUrl = String.fromEnvironment(
    'MUDBASE_BASE_URL',
    defaultValue: 'https://cloud.mudbase.dev',
  );

  static const String mudbaseProjectId = String.fromEnvironment(
    'MUDBASE_PROJECT_ID',
    defaultValue: '6a6d29b2d07caabbbdfc3f8c',
  );

  static const String listsCollectionId = String.fromEnvironment(
    'LISTS_COLLECTION_ID',
    defaultValue: '6a6d29cad07caabbbdfc3f9a',
  );

  static const String cardsCollectionId = String.fromEnvironment(
    'CARDS_COLLECTION_ID',
    defaultValue: '6a6d29cad07caabbbdfc3fad',
  );

  static const String activityCollectionId = String.fromEnvironment(
    'ACTIVITY_COLLECTION_ID',
    defaultValue: '6a6d29cbd07caabbbdfc3fc6',
  );

  /// This is a single shared-board demo, not multi-tenant - every `boardId`
  /// field on every lists/cards/activity document is this one constant.
  /// Must be a real 24-hex-char ObjectId, not an arbitrary slug: the
  /// reference web app's `plan/build-plan.md` documents that Mudbase's query
  /// sanitizer validates any field ending in `Id` as a real ObjectId
  /// reference and rejects a non-ObjectId value like `"main-board"` with
  /// `Invalid ObjectId format for boardId` - confirmed live against this
  /// same project. This is the id of the single document in the `boards`
  /// collection (`6a6d405cd07caabbbdfc5c79`) the web app provisioned.
  static const String boardId = String.fromEnvironment(
    'BOARD_ID',
    defaultValue: '6a6d4072d07caabbbdfc5d3c',
  );

  /// Fails fast at startup (in `main()`) rather than surfacing a confusing
  /// mid-flow 404/401 the first time a screen tries to read an empty
  /// collection id - mirrors the web app's `requireEnv()`
  /// (`web/src/lib/config.ts`) and the sibling Flutter ports' own
  /// `assertConfigured()`. In practice this only fires if a consumer
  /// explicitly overrides one of the defaults above with an empty string.
  static void assertConfigured() {
    final missing = <String>[
      if (mudbaseProjectId.isEmpty) 'MUDBASE_PROJECT_ID',
      if (listsCollectionId.isEmpty) 'LISTS_COLLECTION_ID',
      if (cardsCollectionId.isEmpty) 'CARDS_COLLECTION_ID',
      if (activityCollectionId.isEmpty) 'ACTIVITY_COLLECTION_ID',
      if (boardId.isEmpty) 'BOARD_ID',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required --dart-define values: ${missing.join(', ')}. '
        'See README "Setup" for the full list and how to supply them.',
      );
    }
  }
}
