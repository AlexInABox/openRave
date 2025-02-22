import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'services/backend_handler.dart';

class SearchOverlay extends StatefulWidget {
  final RoomController roomController;

  const SearchOverlay({super.key, required this.roomController});
  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final YoutubeExplode yt = YoutubeExplode();
  List<Song> searchResults = [];
  bool searchResultsLoaded = false;
  TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Search for a new song"),
        automaticBackgroundVisibility: false,
        backgroundColor: Colors.black,
      ),
      backgroundColor: const Color.fromARGB(239, 0, 0, 0),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CupertinoSearchTextField(
                controller: searchController,
                placeholder: "Search for a song",
                onSubmitted: (String value) {
                  populateListOfFoundSongs(value);
                },
                onChanged: (String value) {},
                onSuffixTap: () {
                  searchController.clear();
                  searchResultsLoaded = false;
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 20),
              Expanded(child: buildListViewOfSearchResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildListViewOfSearchResults() {
    if (!searchResultsLoaded) {
      return const Center(
        child: Text(
          "No results yet.",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final result = searchResults[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.1),
          child: GestureDetector(
            onTap: () {
              widget.roomController.changeVideo(result.id);
              Navigator.of(context).pop();
            },
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.08,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                ),
                child: Material(
                  // Use Material with transparency so it doesn't override your container's style.
                  type: MaterialType.transparency,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 5),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        result.coverUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[800],
                            child: const Icon(Icons.error, color: Colors.white),
                          );
                        },
                      ),
                    ),
                    title: Text(
                      result.title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      result.artist,
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> populateListOfFoundSongs(String value) async {
    searchResults.clear();
    searchResultsLoaded = false;
    try {
      final response = await http.get(
        Uri.parse("https://ytms.zeitvertreib.vip/search?title=$value"),
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body); // Parse as List
        searchResults = jsonList.map((json) => Song.fromJson(json)).toList();
        searchResultsLoaded = true;
      } else {
        searchResultsLoaded = false;
        throw Exception("Failed to fetch songs: ${response.statusCode}");
      }
    } catch (e) {
      searchResultsLoaded = false;
      debugPrint("Error fetching songs: $e");
    }

    if (mounted) setState(() {});
  }
}

class Song {
  final String title;
  final String artist;
  final String id;
  final String coverUrl;

  Song({
    required this.title,
    required this.artist,
    required this.id,
    required this.coverUrl,
  });

  // Factory method to create a Song from JSON
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      title: json["title"],
      artist: json["artist"],
      id: json["id"],
      coverUrl:
          "https://yttf.zeitvertreib.vip/?url=https://music.youtube.com/watch?v=${json["id"]}",
    );
  }
}
