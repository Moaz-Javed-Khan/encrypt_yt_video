import 'dart:typed_data';

import 'package:download_video_app/d.dart';
import 'package:flutter/material.dart' hide Key;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Video Downloader')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                const videoUrl = 'https://www.youtube.com/watch?v=QC8iQqtG0hg';

                await downloadVideo(videoUrl, 'newVideo.mp4');
              },
              child: const Text('Download and Encrypt'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoListScreen(),
                  ),
                );
              },
              child: const Text('Show Videos'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> downloadVideo(String videoUrl, String filename) async {
  var yt = YoutubeExplode();

  // Get the video
  var video = await yt.videos.get(videoUrl);

  // Get the manifest
  var manifest = await yt.videos.streamsClient.getManifest(video.id);

  // Get the audio and video streams
  var streamInfo = manifest.muxed.withHighestBitrate();

  // Get the stream
  var stream = yt.videos.streamsClient.get(streamInfo);

  // Get application directory
  var appDocDir = await getApplicationDocumentsDirectory();
  var videoDir = Directory('${appDocDir.path}/videos');

  // Create directory if it doesn't exist
  if (!await videoDir.exists()) {
    await videoDir.create();
  }

  // Create a file for the video
  var filePath = '${videoDir.path}/$filename.mp4';
  var file = File(filePath);
  var fileStream = file.openWrite();

  // Download and write the video
  await for (var data in stream) {
    fileStream.add(data);
  }

  await fileStream.close();

  // Create a file for the encrypted video
  var encryptedFilePath = '${videoDir.path}/${filename}_encrypted.mp4';
  var encryptedFile = File(encryptedFilePath);

  // Encrypt the downloaded video
  await encryptFileInChunks(file, encryptedFile);

  print('Download and encryption complete. '
      'Encrypted file saved at ${encryptedFile.path}');
  yt.close();
}

Future<void> encryptFileInChunks(File inputFile, File outputFile) async {
  var key = "0123456789abcdef0123456789abcdef";
  var iv = "abcdef0123456789";

  final keyBytes = encrypt.Key.fromUtf8(key);
  final ivBytes = encrypt.IV.fromUtf8(iv);

  // final key = encrypt.Key.fromUtf8('15helloTCJTALK20');
  // final iv = encrypt.IV.fromLength(16);
  // final iv = encrypt.IV.allZerosOfLength(16);

  // final keyBytes = key;
  // final ivBytes = iv;

  final encrypter = encrypt.Encrypter(
    encrypt.AES(
      keyBytes,
      // mode: encrypt.AESMode.ecb,
      // mode: encrypt.AESMode.cbc,
      // mode: encrypt.AESMode.ctr,
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
      final dataToEncrypt = buffer.toBytes();
      buffer.clear();
      final encryptedChunk =
          encrypter.encryptBytes(dataToEncrypt, iv: ivBytes).bytes;
      output.add(Uint8List.fromList(encryptedChunk));
    }
  }

  // Handle any remaining data in the buffer
  if (buffer.isNotEmpty) {
    final encryptedChunk =
        encrypter.encryptBytes(buffer.toBytes(), iv: ivBytes).bytes;
    output.add(Uint8List.fromList(encryptedChunk));
  }

  await output.close();
}
