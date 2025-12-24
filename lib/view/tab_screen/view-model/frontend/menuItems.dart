import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/widgets/cached_blob_image.dart';

class MenuItem extends StatelessWidget {
  const MenuItem({
    super.key,
    required this.context,
    required this.imagePath,
    required this.text,
    required this.code,
    required this.price,
    required this.stocks,
  });

  final BuildContext context;
  final String imagePath;
  final String text;
  final String code;
  final String price;
  final String stocks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height / 3,
            decoration: BoxDecoration(
                //border: Border.all(color: primaryColor),
                borderRadius: const BorderRadius.all(Radius.circular(7)),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 0.5,
                      blurRadius: 0.5)
                ]),
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          //color: primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(65),
                        ),
                        child: 

                        CachedBlobImage(
                          width: 10,
                          height: 10,
                          imageUrl: imagePath,
                          tableName: 'food_items',
                          recordId: code,
                          // placeholder: 
                          //       const CircularProgressIndicator(
                          //   color: primaryColor,
                          //   strokeWidth: 2,
                          // ),
                          errorWidget: 
                              const Icon(Icons.error),
                        ),
                        
                        // CachedNetworkImage(
                        //   imageUrl: imagePath,
                        //   placeholder: (BuildContext context, String url) =>
                        //       const Center(
                        //           child: CircularProgressIndicator(
                        //     color: primaryColor,
                        //   )),
                        //   errorWidget: (BuildContext context, String url,
                        //           dynamic error) =>
                        //       const Icon(Icons.error),
                        // ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                //border: Border.all(color: primaryColor),
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(12)),
                                color: Colors.grey.withOpacity(0.1),
                              ),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: const TextStyle(
                                  overflow: TextOverflow.ellipsis,
                                  // fontFamily: 'fontmain',
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  //letterSpacing: 1.2,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "(${code.toUpperCase()})",
                            textAlign: TextAlign.center,
                            // maxLines: 2,
                            style: const TextStyle(
                              fontFamily: 'fontmain',
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              //letterSpacing: 1.2,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    // const Text(
                    //   '1 Piece',
                    //   textAlign: TextAlign.center,
                    //   maxLines: 2,
                    //   style: TextStyle(
                    //     // fontFamily: 'fontmain',
                    //     color: Colors.grey,
                    //     fontWeight: FontWeight.w500,
                    //     letterSpacing: 1.2,
                    //     fontSize: 13,
                    //   ),
                    // ),
                    // // const SizedBox(
                    // //   height: 2,
                    // // ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            '₹$price',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(
                              // fontFamily: 'fontmain',
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              //letterSpacing: 1.2,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            height: MediaQuery.of(context).size.height / 33,
                            width: MediaQuery.of(context).size.width / 5,
                            decoration: BoxDecoration(
                                border: Border.all(color: appbar1),
                                color: Colors.white,
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(6))),
                            child: Center(
                              child: Text(
                                "ADD",
                                style: TextStyle(
                                    fontFamily: 'tabfont',
                                    color: appbar1,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ]),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              height: MediaQuery.of(context).size.height / 29,
              width: MediaQuery.of(context).size.width / 13,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 3, 86, 153),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(7),
                    bottomRight: Radius.circular(15)),
              ),
              child: Column(
                children: [
                  const Text(
                    "Qty",
                    style: TextStyle(
                        fontFamily: 'tabfont',
                        color: Colors.white,
                        fontSize: 8),
                  ),
                  Expanded(
                    child: Text(
                      stocks,
                      style: const TextStyle(
                          fontFamily: 'tabfont',
                          color: Colors.white,
                          fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
