import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class SearchOverlay extends StatefulWidget {
  const SearchOverlay({super.key});

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final YoutubeExplode yt = YoutubeExplode();
  late VideoSearchList searchResults;
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
      backgroundColor: Colors.black87,
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
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: GestureDetector(
            onTap: () {
              // Handle tap events (e.g., navigate to a details page)
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                // Use Material with transparency so it doesn't override your container's style.
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      "https://yttf.zeitvertreib.vip/?url=https://music.youtube.com/watch?v=${result.id}",
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
                    result.author,
                    style: TextStyle(color: Colors.grey[300]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void populateListOfFoundSongs(String value) async {
    try {
      searchResults = await yt.search.search(value);
      searchResultsLoaded = true;
    } catch (e) {
      // Handle errors (e.g., show a snackbar or error widget)
      searchResultsLoaded = false;
    }
    if (mounted) setState(() {});
  }
}
