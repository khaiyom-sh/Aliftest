import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

class AlifTest extends StatefulWidget {
  const AlifTest({Key? key}) : super(key: key);
  @override
  State<AlifTest> createState() => _AlifTestState();
}

class _AlifTestState extends State<AlifTest> {
  List _list = [];
  bool _loader = true;
  // барои ленивая загрузка ҳар маротиба запрос ба АПИ равон мекунаму ҷавобашро гирифта баъд нишон медиҳам, лекин аз ин сайт нафаҳмидам чӣ хел лимит гузошта маълумотҳоро гирам.
  // дар поён барои мисол коди ленивая загрузка меорам.

  @override
  void initState() {
    WidgetsFlutterBinding.ensureInitialized();
    _zapros();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alif Test'),
      ),
      body: Container(
        child: FutureBuilder<List<DB>>(
          future: SQLDB.instance.getDB(),
          builder: (BuildContext context, AsyncSnapshot<List<DB>> snapshot){
            if(!snapshot.hasData){
              return Center(child: CircularProgressIndicator());
            }
            return snapshot.data!.isEmpty
                ? _loader ==true ? Center(child: CircularProgressIndicator()) : Center(child: Text('Пусто'))
                : ListView(children: snapshot.data!.map((list) {
              return Container(
                child: InkWell(
                  onTap: () async{
                    if (!await launchUrl(Uri.parse('https://guidebook.com'+list.url))) {  throw ''; }
                  },
                  child: Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 5))
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(list.name, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                              child: Text(list.endDate, style: TextStyle(fontWeight: FontWeight.w400, color: Colors.black87)),
                            ),
                          ],
                        ),),
                        Container(
                            margin: EdgeInsets.fromLTRB(10, 0, 0, 0),
                            height: 60,
                            width: 60,
                            child: Container(
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image(
                                        image: CachedNetworkImageProvider(list.icon),
                                        fit: BoxFit.cover))
                            )
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),);
          },
        ),
      ),
    );
  }

  void _zapros() async {
    var _response = await http.get(Uri.parse('https://guidebook.com/service/v2/upcomingGuides/'));
    if (_response.statusCode == 200) {
      _list = await jsonDecode(_response.body)['data'];
      await SQLDB.instance.remove();
      for(int i=0; i<_list.length; i++){
        String _name = _list[i]['name'].toString();
        String _endDate = _list[i]['endDate'].toString();
        String _icon = _list[i]['icon'].toString();
        String _url = _list[i]['url'].toString();
        await SQLDB.instance.add(DB(
          name: _name,
          endDate: _endDate,
          icon: _icon,
          url: _url,
        ));
      }

      setState(() {
        _loader = false;
      });
    }else{
      print(_response.statusCode);
      setState(() {
       _loader = false;
      });
    }
  }

  /* Барои ленивая загрузка
      1. переменая limit=3 мемонем
      2. дар itemCount-и ListView  _list.length+1 мекунем
      3. дар itemBuilder условия мемонем
        if(index < _list.length){
            коди будааш
          }else{
            limit = limit+3;
            _zapros();
          }
       4. дар запрос илова мекунем
            body: {
              'limit': limit,
            }
       5. дар АПИ дар запроси SQL лимит мегузорем
          LIMIT limit, 3
   */

}

class DB{
  final int? id;
  final String name;
  final String endDate;
  final String icon;
  final String url;
  DB({this.id, required this.name, required this.endDate, required this.icon, required this.url});

  factory DB.fromMap(Map<String, dynamic> json) => new DB(
    id: json['id'],
    name: json['name'],
    endDate: json['endDate'],
    icon: json['icon'],
    url: json['url'],
  );

  Map<String, dynamic> toMap(){
    return{
      'id':id,
      'name':name,
      'endDate':endDate,
      'icon':icon,
      'url':url,
    };
  }

}

class SQLDB{
  SQLDB._privateConstructor();
  static final SQLDB instance = SQLDB._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async{
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'db.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate (Database db, int version) async{
    await db.execute('''
    CREATE TABLE list(
        id INTEGER PRIMARY KEY,
        name TEXT,
        endDate TEXT,
        icon TEXT,
        url TEXT
      )
    ''');
  }

  Future<List<DB>> getDB() async{
    Database db = await instance.database;
    var list = await db.query('list');
    List<DB> listList = list.isNotEmpty ? list.map((c) => DB.fromMap(c)).toList() : [];
    return listList;
  }

  Future<int> add(DB list) async{
    Database db = await instance.database;
    return await db.insert('list', list.toMap());
  }

  Future<int> remove() async{
    Database db = await instance.database;
    return await db.delete('list');
  }

}
