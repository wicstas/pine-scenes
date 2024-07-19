import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:supabase/supabase.dart';
import 'package:http/http.dart' as http;

const String version = '0.0.1';

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output.',
    )
    ..addFlag(
      'version',
      negatable: false,
      help: 'Print the tool version.',
    );
}

void printUsage(ArgParser argParser) {
  print('Usage: dart pines.dart <flags> [arguments]');
  print(argParser.usage);
}

Future<void> upload(List<String> arguments) async {
  final ArgParser argParser = buildParser();
  try {
    final ArgResults results = argParser.parse(arguments);
    bool verbose = false;

    if (results.wasParsed('help')) {
      printUsage(argParser);
      return;
    }
    if (results.wasParsed('version')) {
      print('pines version: $version');
      return;
    }
    if (results.wasParsed('verbose')) {
      verbose = true;
    }

    final supabase = SupabaseClient("https://nanyhmpqmaagwbjzdtyv.supabase.co",
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5hbnlobXBxbWFhZ3dianpkdHl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTE5MzY0NzksImV4cCI6MjAyNzUxMjQ3OX0.u4hq3swktGeS9pKOUdmOMvdG3kCUwMnrcjoC7y22MqA");

    for (final path in results.rest) {
      try {
        print("Uploading $path");
        await supabase.storage.from('pine').upload(
              path,
              File(path),
            );
      } on StorageException catch (e) {
        if (e.error == "Duplicate") {
          try {
            print("File exists, updating $path instead");
            await supabase.storage.from('pine').update(
                  path,
                  File(path),
                );
          } on StorageException catch (e_) {
            print(e_.message);
          }
        } else {
          print(e.message);
        }
      }
    }

    print('Positional arguments: ${results.rest}');
    if (verbose) {
      print('[VERBOSE] All arguments: ${results.arguments}');
    }
  } on FormatException catch (e) {
    print(e.message);
    print('');
    printUsage(argParser);
  }

  print("Done");
}

getJson(url) async {
  final res = await http.get(Uri.parse(url));
  return json.decode(res.body);
}

fileExists(filePath) {
  return File(filePath).existsSync();
}

download(filePath, url) async {
  final res = await http.get(Uri.parse(url));
  File(filePath).writeAsBytesSync(res.bodyBytes);
}

pprint(jobj) {
  var encoder = JsonEncoder.withIndent("  ");
  print(encoder.convert(jobj));
}

Future<void> downloadPolyHeavenAssets(
    String type, String folder, String extension, bool hasIncludes) async {
  final map = await getJson('https://api.polyhaven.com/assets/?type=$type');

  for (final id in map.keys) {
    final path = hasIncludes ? "$folder/$id/$id.$extension" : "$folder/$id.$extension";
    if (fileExists(path)) {
      print("Skipping $id...");
      continue;
    }
    print(id);
    await download("thumbnail/$folder/$id.jpg", map[id]['thumbnail_url']);
    final itemMap = await getJson('https://api.polyhaven.com/files/$id');
    final itemMapKey = extension == "hdr" ? "hdri" : extension;
    if (itemMap[itemMapKey] == null) {
      print("------------------------------------------");
      print("$id has no $extension file");
      continue;
    }
    final item = itemMap[itemMapKey]['1k'][extension];
    final url = item['url'];
    Directory("$folder/$id").createSync();
    await download(path, url);
    if (hasIncludes) {
      for (final includeId in item['include'].keys) {
        Directory("$folder/$id/textures").createSync();
        await download("$folder/$id/$includeId", item['include'][includeId]['url']);
      }
    }
  }
}

void main(List<String> arguments) async {
  // await downloadPolyHeavenAssets("hdris", "hdr", "hdr", false);
  // await downloadPolyHeavenAssets("textures", "texture", "gltf", true);
  // await downloadPolyHeavenAssets("models", "model", "gltf", true);
  await upload(arguments);

  exit(0);
}
