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
      navigationBar: CupertinoNavigationBar(
        middle: Text("Search for a new song"),
      ),
      backgroundColor: Colors.black87, // Semi-transparent background
      child: Padding(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kMinInteractiveDimension),
        child: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              children: [
                CupertinoSearchTextField(
                  controller: searchController,
                  placeholder: "Search for a song",
                  onSubmitted: (String value) {
                    // Handle the search logic here
                    populateListOfFoundSongs(value);
                  },
                  onChanged: (String value) {},
                  onSuffixTap: () {
                    searchController.clear();
                    searchResultsLoaded = false;
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
                buildListViewOfSearchResults(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  dynamic buildListViewOfSearchResults() {
    if (!searchResultsLoaded) return SizedBox();
    return Material(
      color: Colors.transparent, // Semi-transparent background
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: ListView.builder(
          itemCount: searchResults.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(
                searchResults[index].title,
                style: TextStyle(color: Colors.white),
              ),
              leading: Image.network(
                "https://yttf.zeitvertreib.vip/?url=https://music.youtube.com/watch?v=${searchResults[index].id}",
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            );
          },
          scrollDirection: Axis.vertical,
        ),
      ),
    );
  }

  void populateListOfFoundSongs(String value) async {
    searchResults = await yt.search.search(value);
    searchResultsLoaded = true;
    if (mounted) {
      setState(() {});
    }
  }
}
