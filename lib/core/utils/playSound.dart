import 'package:audioplayers/audioplayers.dart';

Future<void> playSound(String sound) async {
  final AudioPlayer player = AudioPlayer();
  try {
    await player.play(AssetSource(sound));
  } catch (e) {
    print(e);
  }
}
