import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/models/Drugs/drug_model.dart';
import '../../core/services/supabase_image_service.dart';

class EditDrugScreen extends StatefulWidget {
  final cubit;
  final DrugModel drugToEdit;

  const EditDrugScreen({super.key, required this.cubit, required this.drugToEdit});

  @override
  State<EditDrugScreen> createState() => _EditDrugScreenState();
}

class _EditDrugScreenState extends State<EditDrugScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _expiryDateController = TextEditingController();

  XFile? _selectedImage;
  String _currentImageUrl = '';
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _imageRemoved = false;

  @override
  void initState() {
    super.initState();
    _populateFieldsWithCurrentData();
  }

  void _populateFieldsWithCurrentData() {
    final drug = widget.drugToEdit;
    _nameController.text = drug.name;
    _stockController.text = drug.stock.toString();
    _expiryDateController.text = drug.expiryDate;
    _currentImageUrl = drug.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    // Parse current date from the controller if available
    DateTime initialDate = DateTime.now().add(const Duration(days: 30));
    if (_expiryDateController.text.isNotEmpty) {
      try {
        final dateParts = _expiryDateController.text.split('-');
        if (dateParts.length == 3) {
          initialDate = DateTime(
            int.parse(dateParts[0]), // year
            int.parse(dateParts[1]), // month
            int.parse(dateParts[2]), // day
          );
        }
      } catch (e) {
        // If parsing fails, use default date
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _expiryDateController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Update Drug Image',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _imageSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => _selectImageSource(ImageSource.camera),
                ),
                _imageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => _selectImageSource(ImageSource.gallery),
                ),
                _imageSourceOption(
                  icon: Icons.delete,
                  label: 'Remove',
                  onTap: () => _removeImageFromBottomSheet(),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _imageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: icon == Icons.delete ? Colors.red.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 30,
              color: icon == Icons.delete ? Colors.red : Colors.blue,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: icon == Icons.delete ? Colors.red : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectImageSource(ImageSource source) async {
    Navigator.pop(context);
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        _selectedImage = image;
        _imageRemoved = false;
      });
    }
  }

  void _removeImageFromBottomSheet() {
    Navigator.pop(context);
    setState(() {
      _selectedImage = null;
      _imageRemoved = true;
    });
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageRemoved = true;
    });
  }

  Future<void> _updateDrug(cubit) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? finalImageUrl = _currentImageUrl;

      // Handle image changes
      if (_imageRemoved) {
        // User removed the image - delete from Supabase and set empty URL
        if (_currentImageUrl.isNotEmpty) {
          await SupabaseImageService.deleteImage(_currentImageUrl);
        }
        finalImageUrl = '';
      } else if (_selectedImage != null) {
        // User selected a new image - upload it
        setState(() {
          _isUploadingImage = true;
        });

        final String drugId = widget.drugToEdit.id?.toString() ?? 'drug_${DateTime.now().millisecondsSinceEpoch}';

        finalImageUrl = await SupabaseImageService.uploadImage(
          imageFile: _selectedImage!,
          drugId: drugId,
          existingImageUrl: _currentImageUrl.isNotEmpty ? _currentImageUrl : null,
        );

        setState(() {
          _isUploadingImage = false;
        });

        if (finalImageUrl == null) {
          throw Exception('Failed to upload image to Supabase');
        }

        print('Image uploaded successfully: $finalImageUrl');
      }
      // If no changes to image, keep the current URL

      final updatedDrug = DrugModel(
        id: widget.drugToEdit.id,
        name: _nameController.text.trim(),
        stock: int.parse(_stockController.text.trim()),
        expiryDate: _expiryDateController.text.trim(),
        imageUrl: finalImageUrl ?? '',
      );

      await widget.cubit.updateDrug(updatedDrug);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drug updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error updating drug: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating drug: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  Widget _buildImagePreview() {
    if (_imageRemoved) {
      // Show placeholder when image is removed
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Add Image', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    } else if (_selectedImage != null) {
      // Show new selected image
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.file(
          File(_selectedImage!.path),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    } else if (_currentImageUrl.isNotEmpty) {
      // Show existing image from Supabase
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SupabaseImageService.buildNetworkImage(
          imageUrl: _currentImageUrl,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          placeholder: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text('Add Image', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      );
    } else {
      // Show placeholder when no image
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Add Image', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Edit Drug',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => widget.cubit.deleteDrug(widget.drugToEdit.id.toString()).then((_) {
                    Navigator.of(context).pop(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Drug deleted successfully!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }).catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting drug: $e'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }),
                  icon: const Icon(Icons.delete, color: Colors.red,),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                  ),
                ),
              ],
            ),
          ),

          const Divider(thickness: 1),

          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drug Image Section
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey.shade300, width: 2),
                              ),
                              child: _buildImagePreview(),
                            ),
                          ),
                          if (_currentImageUrl.isNotEmpty || _selectedImage != null)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: GestureDetector(
                                onTap: _removeImage,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (_isUploadingImage)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('Uploading image...', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 30),

                    // Drug Name Field
                    _buildInputField(
                      label: 'Drug Name',
                      controller: _nameController,
                      icon: Icons.medication,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter drug name';
                        }
                        if (value.trim().length < 2) {
                          return 'Drug name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Stock Quantity Field
                    _buildInputField(
                      label: 'Stock Quantity',
                      controller: _stockController,
                      icon: Icons.inventory,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter stock quantity';
                        }
                        final stock = int.tryParse(value.trim());
                        if (stock == null || stock < 0) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Expiry Date Field
                    _buildInputField(
                      label: 'Expiry Date',
                      controller: _expiryDateController,
                      icon: Icons.calendar_today,
                      readOnly: true,
                      onTap: _selectDate,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please select expiry date';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _updateDrug(widget.cubit),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Update Drug',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          onTap: onTap,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.blue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
