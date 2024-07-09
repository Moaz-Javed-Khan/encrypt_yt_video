import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Key;
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart';
import 'package:video_player/video_player.dart';

class VideoListScreen extends StatefulWidget {
  @override
  _VideoListScreenState createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  List<File> encryptedVideos = [];

  @override
  void initState() {
    super.initState();
    _loadEncryptedVideos();
  }

  Future<void> _loadEncryptedVideos() async {
    List<File> videos = await getEncryptedVideos();
    setState(() {
      encryptedVideos = videos;
    });

    print(videos);
  }

  Future<List<File>> getEncryptedVideos() async {
    var appDocDir = await getApplicationDocumentsDirectory();
    var videoDir = Directory('${appDocDir.path}/videos');
    if (!await videoDir.exists()) {
      return [];
    }
    return videoDir
        .listSync()
        .where((file) => file.path.endsWith('_encrypted.mp4'))
        .map((file) => File(file.path))
        .toList();
  }

  Future<void> playVideo(File file) async {
    await playDecryptedVideo(context, file);
  }

  Future<void> decryptFileInChunks(File inputFile, File outputFile) async {
    var key = "0123456789abcdef0123456789abcdef";
    var iv = "abcdef0123456789";

    final keyBytes = Key.fromUtf8(key);
    final ivBytes = IV.fromUtf8(iv);

    // final key = Key.fromUtf8('15helloTCJTALK20');
    // final iv = IV.fromLength(16);
    // final iv = IV.allZerosOfLength(16);

    // final keyBytes = key;
    // final ivBytes = iv;

    final encrypter = Encrypter(
      AES(
        keyBytes,
        // mode: AESMode.ecb,
        // mode: AESMode.cbc,
        // mode: AESMode.ctr,
        // padding: 'PKCS7',
        // padding: 'ISO7816-4',
      ),
    );

    final input = inputFile.openRead();
    final output = outputFile.openWrite();

    const int chunkSize = 1024; // Define the chunk size
    final buffer = BytesBuilder();

    await for (var chunk in input) {
      buffer.add(chunk);
      if (buffer.length >= chunkSize) {
        final dataToDecrypt = buffer.toBytes();
        buffer.clear();
        final decryptedChunk =
            encrypter.decryptBytes(Encrypted(dataToDecrypt), iv: ivBytes);
        output.add(Uint8List.fromList(decryptedChunk));
      }
    }

    // Handle any remaining data in the buffer
    if (buffer.isNotEmpty) {
      final decryptedChunk =
          encrypter.decryptBytes(Encrypted(buffer.toBytes()), iv: ivBytes);
      output.add(Uint8List.fromList(decryptedChunk));
    }

    await output.close();
  }

  Future<void> playDecryptedVideo(
      BuildContext context, File encryptedFile) async {
    var decryptedFilePath =
        '${encryptedFile.parent.path}/decrypted_${encryptedFile.uri.pathSegments.last}';
    var decryptedFile = File(decryptedFilePath);

    // Decrypt the file
    await decryptFileInChunks(encryptedFile, decryptedFile);

    // Play the decrypted file
    final player = VideoPlayerController.file(decryptedFile);
    await player.initialize();
    player.play();

    // Show video player in a new screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(player: player),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encrypted Videos'),
      ),
      body: ListView.builder(
        itemCount: encryptedVideos.length,
        itemBuilder: (context, index) {
          File video = encryptedVideos[index];
          return ListTile(
            title: Text(video.path.split('/').last),
            onTap: () => playVideo(video),
          );
        },
      ),
    );
  }
}

class VideoPlayerScreen extends StatelessWidget {
  final VideoPlayerController player;

  VideoPlayerScreen({required this.player});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playing Video'),
      ),
      body: Center(
        child: VideoPlayer(player),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (player.value.isPlaying) {
            player.pause();
          } else {
            player.play();
          }
        },
        child: Icon(
          player.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
