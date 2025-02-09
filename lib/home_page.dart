import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:DavomatYettilik/main.dart'; // Loyiha nomingizga moslang
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:detect_fake_location/detect_fake_location.dart';
import 'package:safe_device/safe_device.dart'; // Qo'shildi: safe_device kutubxonasi
import 'package:cupertino_icons/cupertino_icons.dart'; // Import cupertino_icons

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;
  String message = '';
  bool isFlashOn = false;
  String? kelishQrCode;
  String? ketishQrCode;
  double? expectedLatitude;
  double? expectedLongitude;
  double distanceThreshold = 100;
  String? _selectedCompanyId; // Assuming you have companyId available here

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCompanyDataPgSQL(_selectedCompanyId ??
        'your_default_company_id'); // Replace 'your_default_company_id' with actual companyId if available
  }

  Future<void> _loadUserData() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // Get QR codes (This part might be moved to PL/pgSQL function if needed)
      // final qrData = await supabase
      //     .from('qrcodes')
      //     .select('kelish_qrcode, ketish_qrcode')
      //     .eq('xodim_id', userId)
      //     .maybeSingle();

      // Get location data (This part might be moved to PL/pgSQL function if needed)
      // final locationData = await supabase
      //     .from('location')
      //     .select('latitude, longitude, distance')
      //     .maybeSingle();

      // if (mounted) {
      //   setState(() {
      //     kelishQrCode = qrData?['kelish_qrcode'] as String?;
      //     ketishQrCode = qrData?['ketish_qrcode'] as String?;
      //     expectedLatitude = locationData?['latitude'] as double?;
      //     expectedLongitude = locationData?['longitude'] as double?;
      //     distanceThreshold = (locationData?['distance'] as num?)?.toDouble() ??
      //         100; //default value if null
      //   });
      // }
    } catch (error) {
      print("Error loading user data: $error");
      setState(() {
        message = 'Foydalanuvchi ma\'lumotlarini yuklashda xatolik!';
      });
    }
  }

  Future<void> _loadCompanyDataPgSQL(String companyId) async {
    try {
      final response = await supabase
          .rpc('get_company_data_pgsql', // PL/pgSQL function name
              params: {'company_id': companyId}) // Pass companyId as argument
          .select(); // .execute() o'rniga .select() ishlatildi

      // No status code check needed for raw list response
      // Assuming successful response if no exception is thrown
      final data =
          response; // response is already the data (List<Map<String, dynamic>>)

      if (data != null && data is List && data.isNotEmpty) {
        // Check if data is valid list and not empty
        final companyData =
            data.first; // Assuming function returns a list with one map
        setState(() {
          kelishQrCode = companyData['qr_codes']?['kelish_qrcode'] as String?;
          ketishQrCode = companyData['qr_codes']?['ketish_qrcode'] as String?;
          expectedLatitude = companyData['location']?['latitude'] as double?;
          expectedLongitude = companyData['location']?['longitude'] as double?;
          distanceThreshold =
              (companyData['location']?['distance'] as num?)?.toDouble() ?? 100;
        });
      } else {
        print("RPC error: Response data is invalid or empty: $response");
        setState(() {
          message =
              'Kompaniya ma\'lumotlarini yuklashda xatolik!'; // Indicate data issue
        });
      }
    } catch (error) {
      print("Error loading company data: $error");
      setState(() {
        message = 'Kompaniya ma\'lumotlarini yuklashda xatolik!';
      });
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final cameraStatus = await Permission.camera.status;
      final locationStatus = await Permission.location.status;

      if (!cameraStatus.isGranted) {
        await Permission.camera.request();
      }
      if (!locationStatus.isGranted) {
        await Permission.location.request();
      }

      return await Permission.camera.isGranted &&
          await Permission.location.isGranted;
    } else if (Platform.isIOS) {
      final cameraStatus = await Permission.camera.status;
      final locationWhenInUseStatus = await Permission.locationWhenInUse.status;
      final locationAlwaysStatus = await Permission.locationAlways.status;

      if (!cameraStatus.isGranted) {
        await Permission.camera.request();
      }
      // Ilovadan foydalanish vaqtida joylashuvni so'rash
      if (!locationWhenInUseStatus.isGranted) {
        await Permission.locationWhenInUse.request();
      }
      // Fon rejimida joylashuvni so'rash (agar kerak bo'lsa)
      if (!locationAlwaysStatus.isGranted) {
        await Permission.locationAlways.request();
      }

      return await Permission.camera.isGranted &&
          (await Permission.locationWhenInUse.isGranted ||
              await Permission.locationAlways.isGranted);
    }
    return false;
  }

  Future<bool> _isFakeDevice() async {
    try {
      bool isFakeLocationByDetectFakeLocation =
          await DetectFakeLocation().detectFakeLocation();
      bool isMockLocationBySafeDevice = await SafeDevice
          .isMockLocation; // Qo'shildi: SafeDevice orqali tekshirish

      // Ikkala kutubxona ham haqiqiy joylashuvni tasdiqlasa, haqiqiy deb hisoblaymiz
      bool isRealLocation =
          !isFakeLocationByDetectFakeLocation && !isMockLocationBySafeDevice;

      return isRealLocation; // Agar soxta bo'lsa false qaytaradi, bizga haqiqiy bo'lsa true kerak
    } catch (e) {
      print("Error detecting fake location: $e");
      return true; // Xatolik yuz berganda haqiqiy deb hisoblaymiz (ehtiyot chorasi)
    }
  }

  Future<void> _handleScanLogic(String data) async {
    if (data.isEmpty) return;

    setState(() {
      message = 'Tekshirilmoqda...';
    });

    final userId = supabase.auth.currentUser!.id;

    // Yangi: Bloklangan foydalanuvchini tekshirish
    final blockedUser = await supabase
        .from('blocked')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (blockedUser != null) {
      setState(() {
        message = 'Siz bloklangansiz!'; // Bloklangan xabar
      });
      return; // Funksiyani shu yerda to'xtatish
    }

    final hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      setState(() {
        message = 'Kamera va joylashuvga ruxsat berilmagan.';
      });
      return;
    }

    final isRealDeviceResult = await _isFakeDevice();
    if (!isRealDeviceResult) {
      setState(() {
        message = 'Soxta qurilma aniqlandi!';
      });
      await supabase.from('blocked').insert({
        'user_id': userId
      }); // Bloklangan jadvalga qo'shish (agar allaqachon bo'lmasa)
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (expectedLatitude == null || expectedLongitude == null) {
        setState(() {
          message =
              'Joylashuv ma\'lumotlari yuklanmadi, iltimos ma\'muri bilan bog\'laning!';
        });
        return;
      }

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        expectedLatitude!,
        expectedLongitude!,
      );

      if (distance > distanceThreshold) {
        setState(() {
          message = 'Siz belgilangan joydan uzoqdasiz!';
        });
        return;
      }

      final today = DateTime.now().toLocal().toString().split(' ')[0];
      final now = DateTime.now().toLocal().toIso8601String();

      final existingAttendance = await supabase
          .from('davomat')
          .select()
          .eq('xodim_id', userId)
          .eq('kelish_sana', today)
          .maybeSingle();

      if (kelishQrCode == null || ketishQrCode == null) {
        setState(() {
          message = 'Sizga QR kodlar biriktirilmagan.';
        });
        return;
      }

      if (kelishQrCode == data) {
        if (existingAttendance == null) {
          final response = await supabase.from('davomat').insert({
            'xodim_id': userId,
            'kelish_sana': today,
            'kelish_vaqti': now,
          }).select();

          if (response.isNotEmpty) {
            setState(() {
              message = 'Kelish saqlandi.';
            });
          } else {
            setState(() {
              message = 'Kelish saqlanmadi.';
            });
          }
        } else {
          setState(() {
            message = 'Siz bugun allaqachon kelganingizni qayd etgansiz.';
          });
        }
      } else if (ketishQrCode == data) {
        if (existingAttendance != null &&
            existingAttendance['ketish_vaqti'] == null) {
          final response = await supabase
              .from('davomat')
              .update({
                'ketish_vaqti': now,
              })
              .eq('xodim_id', userId)
              .eq('kelish_sana', today)
              .select();

          if (response.isNotEmpty) {
            setState(() {
              message = 'Ketish saqlandi.';
            });
          } else {
            setState(() {
              message = 'Ketish saqlanmadi.';
            });
          }
        } else if (existingAttendance != null) {
          setState(() {
            message = 'Siz bugun allaqachon ketganingizni qayd etgansiz.';
          });
        } else {
          setState(() {
            message = 'Avval kelganingizni qayd eting.';
          });
        }
      } else {
        setState(() {
          message = 'Boshqa QR kod.';
        });
      }
    } catch (e) {
      setState(() {
        message = 'Xatolik yuz berdi: $e';
      });
    }
  }

  void _onRebuildQrView() {
    setState(() {
      result = null; // Clear the previous result
      message = ''; // Clear the message
    });
    controller?.resumeCamera(); // Resume camera to start scanning again
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600; // Example breakpoint for tablets
    final titleFontSize = isTablet ? 48.0 : 32.0;
    final subtitleFontSize = isTablet ? 24.0 : 18.0;
    final messageFontSize = isTablet ? 20.0 : 16.0;
    var scanArea = isTablet ? 500.0 : 300.0; // Larger scan area for tablets

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Davomat tizimi'),
      ),
      child: SingleChildScrollView(
        // Added SingleChildScrollView here
        child: Column(
          children: <Widget>[
            // Tepaga joylashtirilgan matnlar
            Padding(
              padding: const EdgeInsets.only(top: 80.0),
              child: Column(
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: titleFontSize,
                        color: CupertinoColors.black,
                        fontFamily: 'Arial Black',
                      ),
                      children: <TextSpan>[
                        TextSpan(
                            text: '"Yettilik" ',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(
                            text: 'Davomati',
                            style:
                                const TextStyle(fontWeight: FontWeight.normal)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "QR kodni skanerlash orqali xodimlar davomati tizimiga kirish mumkin.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: CupertinoColors.black.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: CupertinoColors.black.withOpacity(0.6),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: messageFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20), // Added spacing between text and QRView

            // Markazga joylashtirilgan QRView
            _buildQrView(context, scanArea),

            SizedBox(height: 30), // Spacing below QRView

            // Markazga joylashtirilgan "Yangilash" tugmasi
            Center(
              child: CupertinoButton.filled(
                onPressed: _onRebuildQrView,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_2_circlepath,
                        color: CupertinoColors.white),
                    SizedBox(width: 8),
                    Text('Yangilash',
                        style: TextStyle(color: CupertinoColors.white)),
                  ],
                ),
              ),
            ),

            // Pastki qism (Flash tugmasi)
            Padding(
              padding: const EdgeInsets.only(
                  bottom: 50.0, top: 30), // Added top padding here
              child: Center(
                child: CupertinoButton(
                  // Flash button
                  onPressed: () async {
                    await controller?.toggleFlash();
                    setState(() {
                      isFlashOn = !isFlashOn;
                    });
                  },
                  child: Icon(
                    isFlashOn
                        ? CupertinoIcons.bolt_fill
                        : CupertinoIcons.bolt_slash_fill,
                    color: CupertinoColors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrView(BuildContext context, double scanArea) {
    return Container(
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: scanArea,
          height: scanArea,
          child: QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
            overlay: QrScannerOverlayShape(
              borderColor: CupertinoColors.activeGreen,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: scanArea,
            ),
          ),
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) async {
      setState(() {
        result = scanData;
        message = 'Skanerlandi: ${result!.code}';
      });
      controller.pauseCamera();
      await _handleScanLogic(scanData.code ?? '');
      if (message != 'Soxta qurilma aniqlandi!') {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              message = '';
            });
            controller.resumeCamera();
          }
        });
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruxsat berilmagan.')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

extension ParseToString on double {
  LocationAccuracy toLocationAccuracy() {
    if (this <= 10) {
      return LocationAccuracy.high;
    } else if (this <= 100) {
      return LocationAccuracy.medium;
    } else {
      return LocationAccuracy.low;
    }
  }
}
