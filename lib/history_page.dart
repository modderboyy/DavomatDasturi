import 'package:flutter/cupertino.dart';
import 'package:DavomatYettilik/main.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> attendanceHistory = [];
  String message = '';
  bool isLoading = false;
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _loadCachedAttendanceHistory();
    _loadAttendanceHistory();
  }

  Future<void> _loadCachedAttendanceHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedHistory = prefs.getString('attendanceHistory');
    if (cachedHistory != null) {
      setState(() {
        attendanceHistory =
            List<Map<String, dynamic>>.from(jsonDecode(cachedHistory));
      });
    }
  }

  Future<void> _loadAttendanceHistory() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        message = 'Yuklanmoqda...';
      });
    }
    try {
      final userId = supabase.auth.currentUser!.id;
      print('HistoryPage: Foydalanuvchi ID: $userId');

      final response = await supabase
          .from('davomat')
          .select('kelish_sana, kelish_vaqti, ketish_vaqti')
          .eq('xodim_id', userId)
          .order('kelish_sana', ascending: false);

      print('HistoryPage: Supabase javobi: $response');

      if (mounted) {
        setState(() {
          attendanceHistory = List<Map<String, dynamic>>.from(response);
          message = '';
          print(
              'HistoryPage: Davomat tarixi yangilandi: ${attendanceHistory.length} ta yozuv');
        });
        _cacheAttendanceHistory();
      }
    } catch (error) {
      print("Davomat tarixini yuklashda xatolik: $error");
      if (mounted) {
        setState(() {
          message = 'Davomat tarixini yuklashda xatolik bor!';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      _refreshController.refreshCompleted();
    }
  }

  Future<void> _cacheAttendanceHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('attendanceHistory', jsonEncode(attendanceHistory));
  }

  Future<void> _onRefresh() async {
    setState(() {
      isLoading = true;
    });
    await _loadAttendanceHistory();
  }

  @override
  Widget build(BuildContext context) {
    print('HistoryPage: build() funksiyasi ishga tushdi');
    final isDarkMode = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor =
        isDarkMode ? CupertinoColors.white : CupertinoColors.black;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
          middle: const Text('Davomat Tarixi'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _onRefresh,
            child: isLoading
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh),
          )),
      child: SafeArea(
        child: SmartRefresher(
          controller: _refreshController,
          onRefresh: _onRefresh,
          header: const ClassicHeader(
            refreshStyle: RefreshStyle.Follow,
          ),
          child: CupertinoScrollbar(
            child: isLoading
                ? Center(child: CupertinoActivityIndicator())
                : message.isNotEmpty
                    ? Center(
                        child:
                            Text(message, style: TextStyle(color: textColor)))
                    : attendanceHistory.isEmpty
                        ? Center(
                            child: Text('Davomat tarixi topilmadi.',
                                style: TextStyle(color: textColor)))
                        : ColoredBox(
                            color: CupertinoColors.systemRed.withOpacity(0.0),
                            child: ListView.builder(
                              itemCount: attendanceHistory.length,
                              itemBuilder: (context, index) {
                                final attendance = attendanceHistory[index];
                                final kelishSana =
                                    attendance['kelish_sana'] as String?;
                                final kelishVaqti =
                                    attendance['kelish_vaqti'] as String?;
                                final ketishVaqti =
                                    attendance['ketish_vaqti'] as String?;

                                final sanaFormat = DateFormat('dd.MM.yyyy');
                                final vaqtFormat = DateFormat('HH:mm:ss');

                                final formattedKelishSana = kelishSana != null
                                    ? sanaFormat
                                        .format(DateTime.parse(kelishSana))
                                    : 'Noma\'lum sana';
                                final formattedKelishVaqti = kelishVaqti != null
                                    ? vaqtFormat.format(
                                        DateTime.parse(kelishVaqti).toLocal())
                                    : 'Noma\'lum vaqt';
                                final formattedKetishVaqti = ketishVaqti != null
                                    ? vaqtFormat.format(
                                        DateTime.parse(ketishVaqti).toLocal())
                                    : 'Qayd etilmagan';

                                print(
                                    'HistoryPage: ListView itemBuilder ishga tushdi, index: $index');

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemBlue
                                          .withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: CupertinoColors.systemBlue
                                              .withOpacity(0.5),
                                          width: 2),
                                    ),
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Sana: $formattedKelishSana',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: CupertinoColors.white),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Text('Kelish vaqti: ',
                                                style: TextStyle(
                                                    color:
                                                        CupertinoColors.white)),
                                            Text(formattedKelishVaqti,
                                                style: const TextStyle(
                                                    color:
                                                        CupertinoColors.white)),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Text('Ketish vaqti: ',
                                                style: TextStyle(
                                                    color:
                                                        CupertinoColors.white)),
                                            Text(formattedKetishVaqti,
                                                style: const TextStyle(
                                                    color:
                                                        CupertinoColors.white)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ),
      ),
    );
  }
}
