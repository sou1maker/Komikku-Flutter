import 'dart:async';

import 'package:flutter/material.dart';
import 'package:komikku/dex/apis.dart';
import 'package:komikku/dex/models.dart';
import 'package:komikku/dto/manga_dto.dart';
import 'package:komikku/views/details.dart';
import 'package:komikku/widgets/builder_checker.dart';
import 'package:komikku/widgets/manga_list_view_item.dart';
import 'package:komikku/widgets/search_bar.dart';

/// 搜索页面
class Search extends StatefulWidget {
  const Search({Key? key}) : super(key: key);

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  final _streamController = StreamController<List<MangaDto>>();
  final _scrollController = ScrollController();
  final _cacheMangaList = <MangaDto>[];

  String queryString = '';
  int limit = 10;
  int offset = 0;

  Future<void> _addMangaListToSink({bool refresh = false}) async {
    if (refresh) {
      _cacheMangaList.clear();
      offset = 0;
    }

    // TODO: 这段代码有问题，可能是因为异步没有等待的原因。
    _cacheMangaList.addAll(await _searchManga());
    _streamController.sink.add(_cacheMangaList);
    offset += limit;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        toolbarHeight: 50,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: SearchAppBar(
          hintText: '搜索',
          onSubmitted: (value) async {
            queryString = value;
            await _addMangaListToSink(refresh: true);
          },
        ),
        actions: [
          TextButton(
            child: const Text('取消', style: TextStyle(fontSize: 15, color: Colors.black)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: StreamBuilder<List<MangaDto>>(
        stream: _streamController.stream,
        builder: (context, snapshot) {
          if (snapshot.data?.isEmpty ?? true) {
            return const SizedBox();
          }
          return BuilderChecker(
            snapshot: snapshot,
            child: () => ListView.builder(
              controller: _scrollController,
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    /// 在刷新时点击可能会出现index > snapshot.data!.length的情况
                    if (index < snapshot.data!.length) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Details(dto: snapshot.data![index]),
                        ),
                      );
                    }
                  },
                  //TODO: 异步原因，妥协
                  child: snapshot.data!.length > index
                      ? MangaListViewItem(dto: snapshot.data![index])
                      : const SizedBox(),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge && _scrollController.position.pixels != 0) {
        _addMangaListToSink();
      }
    });
  }

  /// 搜索漫画
  Future<List<MangaDto>> _searchManga() async {
    var response = await MangaApi.getMangaListAsync(
      query: MangaListQuery(
        limit: limit,
        offset: offset,
        title: queryString,
        includes: ['cover_art', 'author'],
        contentRating: [
          ContentRating.safe,
          ContentRating.suggestive,
          ContentRating.erotica,
          ContentRating.pornographic
        ],
        availableTranslatedLanguage: ['zh', 'zh-hk'],
      ),
      order: MangaListOrder(relevance: OrderMode.desc),
    );

    return response.data.map((e) => MangaDto.fromSource(e)).toList();
  }
}
