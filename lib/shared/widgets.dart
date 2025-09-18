import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void navigateTo(context, widget) => Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );

void navigateAndFinish(context, widget) => Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
      (route) => false,
    );

Widget myDivider({
  Color color = Colors.amber,
}) =>
    Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 20.0,
      ),
      child: Container(
        width: double.infinity,
        height: 1.0,
        color: color,
      ),
    );

class CustomDropDownMenu extends StatelessWidget {
  const CustomDropDownMenu({
    super.key,
    required this.controller,
    required this.screenWidth,
    required this.screenRatio,
    required this.entries,
    required this.onSelected,
    this.textColor = Colors.black,
    this.titleColor = Colors.black,
    this.textSize = 20,
    this.titleSize = 20,
    this.space = 10,
    this.title,
    this.showTitle = true,
  });

  final String? title;
  final Color textColor;
  final Color titleColor;
  final double textSize;
  final double titleSize;
  final TextEditingController controller;
  final double screenWidth;
  final double screenRatio;
  final List<DropdownMenuEntry> entries;
  final bool showTitle;

  // ignore: prefer_typing_uninitialized_variables
  final onSelected;
  final double space;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        if (showTitle)
          Container(
              margin: const EdgeInsets.all(5),
              child: Text(title!,
                  style: TextStyle(fontSize: titleSize, color: titleColor))),
        SizedBox(
          height: space,
        ),
        SizedBox(
          width: max(screenWidth * screenRatio, 300),
          child: Container(
            margin: const EdgeInsets.all(5),
            child: Align(
              alignment: Alignment.center,
              child: DropdownMenu(
                hintText: title,
                textStyle: TextStyle(
                    fontSize: textSize, fontFamily: "Cairo", color: textColor),
                requestFocusOnTap: true,
                controller: controller,
                menuHeight: 200,
                enableFilter: true,
                onSelected: onSelected,
                width: screenWidth * screenRatio - 2 * 10,
                dropdownMenuEntries: entries,
              ),
            ),
          ),
        ),
        const SizedBox(
          height: 5,
        )
      ],
    );
  }
}

Widget customTextField(
    {required TextEditingController controller,
    required String label,
    bool isPassword = false,
    Function(String)? onSubmit,
    Function(String)? onChange,
    Function()? onTap,
    bool isClickable = true,
    String? Function(String?)? validator,
    String? hintText,
    Color labelColor = Colors.black,
    Color hintColor = Colors.black,
    IconData? prefixIcon,
    IconData? suffixIcon,
    Color? iconColor,
    Color? suffixIconColor,
    Color? prefixIconColor,
    VoidCallback? prefixFunction,
    VoidCallback? suffixFunction,
    Color? errorStyleColor,
    keyboardType = TextInputType.text,
    textDirection = TextDirection.rtl,
    }) {
  return TextFormField(
    controller: controller,
    obscureText: isPassword,
    keyboardType: keyboardType,
    onFieldSubmitted: onSubmit,
    onChanged: onChange,
    onTap: onTap,
    enabled: isClickable,
    validator: validator,
    cursorColor: Colors.black,
    textDirection: textDirection,
    style: TextStyle(color: labelColor),
    decoration: InputDecoration(
      hintTextDirection: textDirection,
      labelText: label,
      hintText: hintText,
      labelStyle: TextStyle(color: labelColor),
      hintStyle: TextStyle(color: hintColor),
      prefixIcon: prefixIcon != null
          ? IconButton(
              onPressed: prefixFunction,
              icon:
                  Icon(prefixIcon, color: prefixIconColor ?? Colors.white),
            )
          : null,
      suffix: IconButton(onPressed: suffixFunction, icon: Icon(suffixIcon, color: suffixIconColor ?? Colors.white)),
      border: const OutlineInputBorder(),
      errorStyle: TextStyle(color: errorStyleColor ?? Colors.red),
    ),
  );
}

Widget customTextButton(
    {
      required VoidCallback onPressed,
      required String text,
      Color textColor = Colors.black,
      Color bgColor = Colors.white,
      Color hoverColor = Colors.white,
      double textSize = 16,
      double radius = 10,

    }
    ){
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: textColor,
        fontSize: textSize,
      ),
    ),
  );
}


class CustomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color textColor;
  final Color bgColor;
  final double textSize;
  final double radius;

  const CustomButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.textColor = Colors.black,
    this.bgColor = Colors.white,
    this.textSize = 16,
    this.radius = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: textSize,
        ),
      ),
    );
  }
}

class CustomDatePicker extends StatefulWidget {
  final String label;
  final DateTime? initialDate;
  final int? daysOffset;
  final ValueChanged<DateTime>? onDateChanged;

  const CustomDatePicker({
    Key? key,
    this.label = 'Pick Date',
    this.initialDate,
    this.daysOffset,
    this.onDateChanged,
  }) : super(key: key);

  @override
  State<CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime day = DateTime.now().add( Duration(days: widget.daysOffset ?? 1));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? day,
      firstDate: DateTime(2025),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      if (widget.onDateChanged != null) {
        widget.onDateChanged!(picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _pickDate(context),
      child: Text(
        _selectedDate != null
            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
            : widget.label,
      ),
    );
  }
}

// Widget showImage(BuildContext context, {
//   required String imagePath,
//   required Function ()? onChangePressed,
// }) {
//   return AlertDialog(
//     backgroundColor: Colors.transparent,
//     content: OctoImage(image: FileImage(File(imagePath))),
//     actions: [
//       Container(
//         width: MediaQuery.of(context).size.width * 0.3,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(10.0),
//         ),
//         child: TextButton(
//           onPressed: () => Navigator.of(context).pop(),
//           child: const Text(backButton),
//         ),
//       ),
//       Container(
//         width: MediaQuery.of(context).size.width * 0.3,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(10.0),
//         ),
//         child: TextButton(
//           onPressed: () => {
//             if (onChangePressed != null) {
//               onChangePressed()
//             } else {
//               Navigator.of(context).pop()
//             }
//           },
//           child: const Text(changeButton),
//         ),
//       ),
//     ],
//   );
// }