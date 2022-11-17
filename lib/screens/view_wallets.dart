import 'dart:convert';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cryptowallet/main.dart';
import 'package:cryptowallet/utils/app_config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:flutter_gen/gen_l10n/app_localization.dart';

import '../utils/rpc_urls.dart';

class ViewWallets extends StatefulWidget {
  final List data;
  final String currentPhrase;
  const ViewWallets({Key key, this.data, this.currentPhrase}) : super(key: key);
  @override
  State<ViewWallets> createState() => _ViewWalletsState();
}

class _ViewWalletsState extends State<ViewWallets> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  TextEditingController walletName = TextEditingController();
  RxList seedList = [].obs;
  RxBool toggler = false.obs;

  @override
  void dispose() {
    walletName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: Text(AppLocalizations.of(context).wallet)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Obx(() {
            if (seedList == null || seedList.isEmpty) {
              seedList.value = widget.data;
            }

            List<Widget> userWallets = <Widget>[];
            if (seedList != null) {
              for (int index = 0; index < seedList.length; index++) {
                userWallets.add(Dismissible(
                  onDismissed: (DismissDirection direction) {
                    toggler.value = !toggler.value;
                  },
                  key: UniqueKey(),
                  confirmDismiss: (DismissDirection direction) async {
                    if (direction.name == 'endToStart') {
                      return await _deleteWallet(index);
                    }
                    return await _editWalletName(index);
                  },
                  child: GestureDetector(
                    onTap: () async {
                      final pref = Hive.box(secureStorageKey);
                      await pref.put(
                        currentMmenomicKey,
                        seedList[index]['phrase'],
                      );
                      await pref.put(
                        currentUserWalletNameKey,
                        seedList[index]['name'],
                      );

                      RestartWidget.restartApp(context);
                    },
                    child: Container(
                      color: Colors.transparent,
                      width: double.infinity,
                      height: 70,
                      child: Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 5),
                        child: Center(
                            child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  seedList[index]['name'] ??
                                      '${AppLocalizations.of(context).mainWallet} ${seedList.indexOf(seedList[index]) + 1}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.currentPhrase ==
                                            seedList[index]['phrase']
                                        ? Colors.blue
                                        : null),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: widget.currentPhrase ==
                                          seedList[index]['phrase']
                                      ? const Icon(
                                          Icons.check,
                                          size: 20,
                                          color: Colors.white,
                                        )
                                      : Container(),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ),
                    ),
                  ),
                  secondaryBackground: Container(
                    color: Colors.red,
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    alignment: Alignment.centerRight,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  background: Container(
                    color: Colors.blue,
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    alignment: Alignment.centerLeft,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.edit,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ));
              }
            }
            return Column(
              children: userWallets,
            );
          }),
        ),
      ),
    );
  }

  Future<bool> _editWalletName(int index) async {
    Get.closeAllSnackbars();

    final pref = Hive.box(secureStorageKey);
    List mnemonicsList = json.decode(pref.get(mnemonicListKey));
    String currentmnemonic = pref.get(currentMmenomicKey);

    final result = await AwesomeDialog(
      showCloseIcon: false,
      context: context,
      closeIcon: const Icon(
        Icons.close,
      ),
      onDissmissCallback: (_) {},
      autoDismiss: false,
      animType: AnimType.SCALE,
      dialogType: DialogType.INFO,
      keyboardAware: true,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            Text(
              AppLocalizations.of(context).editWalletName,
            ),
            const SizedBox(
              height: 10,
            ),
            Material(
              elevation: 0,
              color: Colors.blueGrey.withAlpha(40),
              child: TextFormField(
                controller: walletName
                  ..text = (mnemonicsList[index]['name'] ?? ''),
                autofocus: true,
                minLines: 1,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  labelText: AppLocalizations.of(context).walletName,
                  prefixIcon: const Icon(Icons.text_fields),
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            AnimatedButton(
              isFixedHeight: false,
              text: AppLocalizations.of(context).ok,
              pressEvent: () async {
                FocusManager.instance.primaryFocus?.unfocus();

                if (walletName.text.trim().isEmpty) {
                  Get.snackbar(
                    '',
                    AppLocalizations.of(context).enterName,
                    colorText: Colors.white,
                    backgroundColor: Colors.red,
                  );

                  Get.back(result: false);
                  return;
                }

                mnemonicsList[index]['name'] = walletName.text.trim();
                if (mnemonicsList[index]['phrase'] == currentmnemonic) {
                  await pref.put(
                    currentUserWalletNameKey,
                    mnemonicsList[index]['name'],
                  );
                }
                await pref.put(
                  mnemonicListKey,
                  json.encode(mnemonicsList),
                );
                seedList = json.decode(pref.get(mnemonicListKey));

                Get.back(result: true);
              },
            )
          ],
        ),
      ),
    ).show();
    return result ?? false;
  }

  Future<bool> _deleteWallet(int index) async {
    Get.closeAllSnackbars();

    final pref = Hive.box(secureStorageKey);
    List mnemonicsList = json.decode(pref.get(mnemonicListKey));

    if (pref.get(currentMmenomicKey).toString().toLowerCase() ==
        mnemonicsList[index]['phrase'].toString().toLowerCase()) {
      const secondsToShowError = Duration(seconds: 2);
      Get.snackbar(
        '',
        'Can not delete currently used wallet',
        colorText: Colors.white,
        backgroundColor: Colors.red,
      );
      return false;
    }
    bool deleted = await AwesomeDialog(
      context: context,
      dialogType: DialogType.WARNING,
      animType: AnimType.BOTTOMSLIDE,
      autoDismiss: false,
      closeIcon: const Icon(
        Icons.close,
      ),
      onDissmissCallback: (type) {},
      dismissOnTouchOutside: true,
      title: AppLocalizations.of(context).confirmWalletDelete,
      btnOkText: AppLocalizations.of(context).delete,
      btnOkColor: Colors.red,
      btnCancelColor: appBackgroundblue,
      desc: AppLocalizations.of(context).confirmWalletDeleteDescription,
      btnCancelOnPress: () {
        Get.back(result: false);
      },
      btnOkOnPress: () async {
        if (await authenticate(context)) {
          mnemonicsList.removeAt(index);

          await pref.put(
            mnemonicListKey,
            json.encode(mnemonicsList),
          );

          seedList.value = mnemonicsList;
          Get.back(result: true);
        } else {
          Get.back(result: false);
        }
      },
    ).show();

    return deleted;
  }
}
