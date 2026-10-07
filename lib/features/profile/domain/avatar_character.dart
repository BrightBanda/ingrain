/// The characters a learner can choose to represent them.
///
/// `id` is what the profile stores. Ids are permanent: removing or renaming one
/// would leave every profile that chose it on the [fallback].
enum AvatarCharacter {
  neko('neko', 'Neko', 'ねこ', 'Curious cat'),
  kitsune('kitsune', 'Kitsune', 'きつね', 'Clever fox'),
  shiba('shiba', 'Shiba', 'しば', 'Loyal pup'),
  tanuki('tanuki', 'Tanuki', 'たぬき', 'Playful trickster'),
  panda('panda', 'Panda', 'パンダ', 'Calm and steady'),
  usagi('usagi', 'Usagi', 'うさぎ', 'Quick learner'),
  kuma('kuma', 'Kuma', 'くま', 'Big-hearted bear'),
  kappa('kappa', 'Kappa', 'かっぱ', 'River spirit'),
  oni('oni', 'Oni', 'おに', 'Friendly ogre'),
  ninja('ninja', 'Ninja', 'にんじゃ', 'Silent studier'),
  daruma('daruma', 'Daruma', 'だるま', 'Never gives up'),
  onigiri('onigiri', 'Onigiri', 'おにぎり', 'Snack-sized hero');

  const AvatarCharacter(this.id, this.name, this.kana, this.tagline);

  final String id;
  final String name;
  final String kana;
  final String tagline;

  static const fallback = AvatarCharacter.neko;

  static AvatarCharacter fromId(String? id) =>
      values.where((character) => character.id == id).firstOrNull ?? fallback;
}
