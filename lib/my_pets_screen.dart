// my_pets_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class MyPetsScreen extends StatefulWidget {
  final bool isModal;
  // NOTE: If you intend to use this screen only for form registration now,
  // the 'isModal' property might become redundant.
  const MyPetsScreen({Key? key, this.isModal = false}) : super(key: key);

  @override
  State<MyPetsScreen> createState() => _MyPetsScreenState();
}

class _MyPetsScreenState extends State<MyPetsScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  User? _currentUser;
  // MODIFIED: _showRegistrationForm is set to true on init, and no longer used for toggling.
  bool _showRegistrationForm = true;
  DocumentSnapshot? _editingPet;
  bool _isLoadingForm = false;

  final TextEditingController _petNameController = TextEditingController();
  final TextEditingController _petWeightController = TextEditingController();
  final TextEditingController _petBirthdateController = TextEditingController();
  final TextEditingController _foodBrandController = TextEditingController();
  final TextEditingController _numberOfMealsController =
      TextEditingController();
  bool _morningFeeding = false;
  TextEditingController _morningTimeController = TextEditingController();
  bool _afternoonFeeding = false;
  TextEditingController _afternoonTimeController = TextEditingController();
  bool _eveningFeeding = false;
  TextEditingController _eveningTimeController = TextEditingController();

  final TextEditingController _morningFoodGramsController =
      TextEditingController();
  final TextEditingController _afternoonFoodGramsController =
      TextEditingController();
  final TextEditingController _eveningFoodGramsController =
      TextEditingController();

  bool _bringOwnFood = false;

  // NEW CONTROLLER: To capture custom breed when 'Other' is selected
  final TextEditingController _customPetBreedController =
      TextEditingController();

  File? _vaccinationRecordImageFile;
  File? _petProfileImageFile;

  String? _vaccinationRecordImageUrl;
  String? _petProfileImageUrl;

  // State variables for Dropdown values
  String? _selectedPetType;
  // NEW STATE VARIABLE FOR BREED
  String? _selectedPetBreed;
  String? _selectedGender;
  String? _selectedCageType;
  String? _selectedFoodBrand;

  // ADDED: State for dynamically loaded breeds and the stream listener
  // This map will store the data fetched from Firestore: {'Dog': ['Aspin', 'Shih Tzu'], 'Cat': ['Puspin', ...]}
  Map<String, List<String>> _availableBreeds = {};
  late StreamSubscription<DocumentSnapshot> _breedSubscription;

  // *****************************************************************
  // FIX: ADDED HARDCODED DEFAULT BREEDS AS FALLBACK
  // *****************************************************************
  static const Map<String, List<String>> _defaultPetBreeds = {
    'Dog': [
      'Aspin (Asong Pinoy)',
      'Shih Tzu',
      'Labrador Retriever',
      'Golden Retriever',
      'Poodle (Toy/Miniature/Standard)',
      'Pug',
      'Pomeranian',
      'German Shepherd',
      'Siberian Husky',
      'Beagle',
      'Chihuahua',
    ],
    'Cat': [
      'Puspin (Pusang Pinoy)',
      'Persian',
      'Siamese',
      'British Shorthair',
      'Maine Coon',
      'Ragdoll',
      'Bengal',
    ],
  };
  // *****************************************************************

  // Dropdown Item Lists
  final List<String> _petTypes = ['Dog', 'Cat'];
  final List<String> _genders = ['Male', 'Female'];
  final List<String> _cageTypes = [
    'Small Kennel',
    'Large Kennel',
    'Other',
  ]; // 'Other' is often present in these types
  final List<String> _foodBrands = [
    'Puppy Kibble',
    'Pedigree',
    'Royal Canin',
    'Acana',
    'Premium',
    'Other', // 'Other' is often present in these types
  ];

  static const String CLOUDINARY_CLOUD_NAME = 'dlec25zve';
  static const String CLOUDINARY_UPLOAD_PRESET = 'pet_photo_preset';

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
    // Set initial breeds to defaults before listening to Firestore
    _availableBreeds = _defaultPetBreeds;

    // Call the listener function to fetch and update breeds in real-time
    _listenToBreeds();
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _petWeightController.dispose();
    _petBirthdateController.dispose();
    _foodBrandController.dispose();
    _numberOfMealsController.dispose();
    _morningTimeController.dispose();
    _afternoonTimeController.dispose();
    _eveningTimeController.dispose();
    _morningFoodGramsController.dispose();
    _afternoonFoodGramsController.dispose();
    _eveningFoodGramsController.dispose();
    // ADDED: Dispose the new custom breed controller
    _customPetBreedController.dispose();
    // Cancel the breed subscription to prevent memory leaks
    _breedSubscription.cancel();
    super.dispose();
  }

  // --- NEW: Firestore Listener for Breeds ---
  void _listenToBreeds() {
    // Reference the Firestore document where the admin updates the breeds
    // This MUST match the document ID used in your JavaScript admin panel: 'config/petBreeds'
    final breedRef = _firestore.collection('petsp').doc('petBreeds');

    // Listen for real-time updates to the breed list
    _breedSubscription = breedRef.snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null) {
            setState(() {
              // Convert the fetched data map<String, dynamic> to map<String, List<String>>
              _availableBreeds = data.map(
                (key, value) => MapEntry(key, List<String>.from(value)),
              );

              // Ensure 'Other' is present in the dynamically loaded list
              _availableBreeds.forEach((key, value) {
                if (!value.contains('Other')) {
                  value.add('Other');
                }
              });
            });
            print('Breeds updated from Firestore: $_availableBreeds');
          }
        } else {
          // FIX: Use the default hardcoded breeds if the Firestore document is not found.
          setState(() {
            _availableBreeds = _defaultPetBreeds;
          });
          print(
            'Breed configuration document not found. Using default breeds.',
          );
        }
      },
      onError: (error) {
        print('Error listening to breeds: $error');
        // In a production app, you might show a persistent warning here
      },
    );
  }

  void _clearForm() {
    _petNameController.clear();
    _petWeightController.clear();
    _petBirthdateController.clear();
    _foodBrandController.clear();
    _numberOfMealsController.clear();
    _morningTimeController.clear();
    _afternoonTimeController.clear();
    _eveningTimeController.clear();
    _morningFoodGramsController.clear();
    _afternoonFoodGramsController.clear();
    _eveningFoodGramsController.clear();
    // ADDED: Clear the new custom breed controller
    _customPetBreedController.clear();

    setState(() {
      _selectedPetType = null;
      // Clear the selected breed
      _selectedPetBreed = null;
      _selectedGender = null;
      _selectedCageType = null;
      _selectedFoodBrand = null;
      _morningFeeding = false;
      _afternoonFeeding = false;
      _eveningFeeding = false;
      _bringOwnFood = false;
      _vaccinationRecordImageFile = null;
      _petProfileImageFile = null;
      _vaccinationRecordImageUrl = null;
      _petProfileImageUrl = null;
      _editingPet = null;
      // _showRegistrationForm remains true as we are dedicating this screen to the form
    });
  }

  // NOTE: This function is now redundant as we removed the pet list, but it's kept
  // in case the user's workflow still relies on starting with a prefilled form.
  void _prefillFormForEdit(DocumentSnapshot petDoc) {
    _editingPet = petDoc;
    final petData = petDoc.data() as Map<String, dynamic>;

    final String? foodBrandFromData = petData['foodBrand'] as String?;
    final String? petBreedFromData = petData['petBreed'] as String?;

    _petNameController.text = petData['petName'] ?? '';
    _petWeightController.text = petData['petWeight'] ?? '';
    _petBirthdateController.text = petData['dateOfBirth'] ?? '';
    _foodBrandController.text = foodBrandFromData ?? '';
    _numberOfMealsController.text = petData['numberOfMeals'] ?? '';
    _morningTimeController.text = petData['morningTime'] ?? '';
    _afternoonTimeController.text = petData['afternoonTime'] ?? '';
    _eveningTimeController.text = petData['eveningTime'] ?? '';
    _morningFoodGramsController.text = petData['morningFoodGrams'] ?? '';
    _afternoonFoodGramsController.text = petData['afternoonFoodGrams'] ?? '';
    _eveningFoodGramsController.text = petData['eveningFoodGrams'] ?? '';

    setState(() {
      _selectedPetType = _petTypes.contains(petData['petType'])
          ? petData['petType']
          : null;

      // Set the selected breed from the stored data
      _selectedPetBreed = petBreedFromData;

      // NEW: Logic to handle 'Other' breed during edit
      if (petBreedFromData != null && petBreedFromData.startsWith('Other:')) {
        // Set the dropdown to 'Other' if the stored value is a custom breed
        _selectedPetBreed = 'Other';
        // Extract the custom text part and set the custom controller
        // 'Other:'.length is 6
        _customPetBreedController.text = petBreedFromData.substring(6).trim();
      } else {
        _customPetBreedController.text = '';
      }

      _selectedGender = _genders.contains(petData['petGender'])
          ? petData['petGender']
          : null;
      _selectedCageType = _cageTypes.contains(petData['cageType'])
          ? petData['cageType']
          : null;

      _selectedFoodBrand = foodBrandFromData;

      _morningFeeding = petData['morningFeeding'] ?? false;
      _afternoonFeeding = petData['afternoonFeeding'] ?? false;
      _eveningFeeding = petData['eveningFeeding'] ?? false;
      _bringOwnFood = petData['bringOwnFood'] ?? false;

      _vaccinationRecordImageUrl = petData['vaccinationRecordImageUrl'];
      _petProfileImageUrl = petData['petProfileImageUrl'];
      _vaccinationRecordImageFile = null;
      _petProfileImageFile = null;

      _showRegistrationForm = true;
    });
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        controller.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  Future<void> _selectTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  // Helper method to pick image
  Future<void> _pickImage(
    Function(File?) onPicked,
    BuildContext context,
  ) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      if (mounted) {
        onPicked(File(pickedFile.path));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image selected.')));
      }
    }
  }

  // Method to upload image to Cloudinary
  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    if (CLOUDINARY_CLOUD_NAME == 'YOUR_ACTUAL_CLOUD_NAME' ||
        CLOUDINARY_UPLOAD_PRESET == 'YOUR_UNSIGNED_UPLOAD_PRESET_NAME') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cloudinary credentials not set up. Please update CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET in my_pets_screen.dart.',
            ),
          ),
        );
      }
      return null;
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final result = jsonDecode(utf8.decode(responseData));
        return result['secure_url'];
      } else {
        final responseData = await response.stream.bytesToString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cloudinary upload failed: ${response.statusCode}, ${responseData}',
              ),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading to Cloudinary: $e')),
        );
      }
      return null;
    }
  }

  void _submitPetForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingForm = true;
    });

    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in. Please log in to manage pets.'),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _isLoadingForm = false;
      });
      return;
    }

    try {
      if (_numberOfMealsController.text.isNotEmpty &&
          int.tryParse(_numberOfMealsController.text) == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Number of Meals per day must be a valid number, or left empty.',
              ),
            ),
          );
        }
        if (!mounted) return;
        setState(() {
          _isLoadingForm = false;
        });
        return;
      }

      if (_morningFeeding &&
          _morningFoodGramsController.text.isNotEmpty &&
          double.tryParse(_morningFoodGramsController.text) == null) {
        _showSnackBar('Morning food grams must be a valid number.');
        setState(() {
          _isLoadingForm = false;
        });
        return;
      }
      if (_afternoonFeeding &&
          _afternoonFoodGramsController.text.isNotEmpty &&
          double.tryParse(_afternoonFoodGramsController.text) == null) {
        _showSnackBar('Afternoon food grams must be a valid number.');
        setState(() {
          _isLoadingForm = false;
        });
        return;
      }
      if (_eveningFeeding &&
          _eveningFoodGramsController.text.isNotEmpty &&
          double.tryParse(_eveningFoodGramsController.text) == null) {
        _showSnackBar('Evening food grams must be a valid number.');
        setState(() {
          _isLoadingForm = false;
        });
        return;
      }

      // Handle Image Uploads... (omitted for brevity, assume success)

      // Handle Vaccination Record Image Upload
      String? finalVaccinationRecordImageUrl = _vaccinationRecordImageUrl;
      if (_vaccinationRecordImageFile != null) {
        final uploadedUrl = await _uploadImageToCloudinary(
          _vaccinationRecordImageFile!,
        );
        if (uploadedUrl != null) {
          finalVaccinationRecordImageUrl = uploadedUrl;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload vaccination record image.'),
              ),
            );
          }
          finalVaccinationRecordImageUrl = _vaccinationRecordImageUrl;
        }
      }

      // Handle Pet Profile Image Upload
      String? finalPetProfileImageUrl = _petProfileImageUrl;
      if (_petProfileImageFile != null) {
        final uploadedUrl = await _uploadImageToCloudinary(
          _petProfileImageFile!,
        );
        if (uploadedUrl != null) {
          finalPetProfileImageUrl = uploadedUrl;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload pet profile image.'),
              ),
            );
          }
          finalPetProfileImageUrl = _petProfileImageUrl;
        }
      }

      // NEW LOGIC: Determine the final breed value to save
      final String? finalPetBreed = _selectedPetBreed == 'Other'
          ? 'Other: ${_customPetBreedController.text.trim()}'
          : _selectedPetBreed;

      final Map<String, dynamic> petData = {
        'ownerUserId': currentUser.uid,
        'petName': _petNameController.text.trim(),
        'petType': _selectedPetType,
        // Use the selected breed or the custom text
        'petBreed': finalPetBreed,
        'petWeight': _petWeightController.text.trim(),
        'dateOfBirth': _petBirthdateController.text.trim(),
        'petGender': _selectedGender,
        'cageType': _selectedCageType,
        'foodBrand': _selectedFoodBrand,
        'numberOfMeals': _numberOfMealsController.text.trim(),
        'bringOwnFood': _bringOwnFood,
        'morningFeeding': _morningFeeding,
        'morningTime': _morningTimeController.text.trim(),
        'morningFoodGrams': _morningFeeding
            ? _morningFoodGramsController.text.trim()
            : '',
        'afternoonFeeding': _afternoonFeeding,
        'afternoonTime': _afternoonTimeController.text.trim(),
        'afternoonFoodGrams': _afternoonFeeding
            ? _afternoonFoodGramsController.text.trim()
            : '',
        'eveningFeeding': _eveningFeeding,
        'eveningTime': _eveningTimeController.text.trim(),
        'eveningFoodGrams': _eveningFeeding
            ? _eveningFoodGramsController.text.trim()
            : '',
        'vaccinationRecordImageUrl': finalVaccinationRecordImageUrl,
        'petProfileImageUrl': finalPetProfileImageUrl,
      };

      if (_editingPet == null) {
        petData['registeredAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('petsp').add(petData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet registered successfully!')),
          );
        }
      } else {
        await _firestore
            .collection('petsp')
            .doc(_editingPet!.id)
            .update(petData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet updated successfully!')),
          );
        }
      }

      _clearForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save pet: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingForm = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB74D)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
      validator: validator,
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB74D)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
      onTap: () => _selectDate(context, controller),
      validator: validator,
    );
  }

  Widget _buildTimeField(
    BuildContext context,
    TextEditingController controller,
    String labelText,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB74D)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
      onTap: () => _selectTime(context, controller),
    );
  }

  Widget _buildFoodGramsField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.number,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB74D)),
        suffixText: 'grams',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
      validator: validator,
    );
  }

  // ***************************************************************
  // FIX: MODIFIED _buildDropdownField to remove 'Other' but keep functional
  // ***************************************************************
  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required String labelText,
    required IconData icon,
    required void Function(String?)? onChanged,
    String? Function(String?)? validator,
    bool allowOther = true, // NEW PARAMETER to control 'Other' option
  }) {
    // Determine the value displayed in the dropdown text field
    String? displayValue = value;
    if (value != null && value.startsWith('Other:') && !allowOther) {
      // If the selected value is 'Other:...' but 'Other' is not allowed,
      // we assume the user is editing an old record. Show the custom text if possible.
      displayValue = value;
    } else if (value != null && value.startsWith('Other:')) {
      // If the value is a custom 'Other:...' value, use 'Other' for the dropdown state
      displayValue = 'Other';
    }

    // 1. Prepare the initial set of items
    final Set<String> uniqueItemsSet = items.toSet();

    // 2. Decide the final list based on the allowOther flag
    List<String> finalItems = [];
    if (allowOther) {
      // For functional fields (like Pet Breed), always ensure 'Other' is an option
      if (!uniqueItemsSet.contains('Other')) {
        uniqueItemsSet.add('Other');
      }
      finalItems = uniqueItemsSet.toList();
    } else {
      // For restricted fields (Pet Type, Cage Type, Food Brand), remove 'Other'
      finalItems = uniqueItemsSet.where((item) => item != 'Other').toList();

      // IMPORTANT: Ensure the currently selected value is available in the list
      // even if it was "Other" (for backward compatibility/editing).
      if (value != null &&
          value.startsWith('Other:') &&
          !finalItems.contains(value)) {
        finalItems.add(value);
        displayValue = value; // Show the full custom value as the selection
      }
    }

    // Sort the list for clean display (optional, but good practice)
    finalItems.sort();

    return DropdownButtonFormField<String>(
      // Use displayValue for the dropdown state
      value: displayValue,
      items: finalItems.map((String item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      // The onChanged handler is now always used (NOT NULL), making the dropdown clickable
      onChanged: onChanged,

      // Always show the standard dropdown arrow, as the field is now functional
      icon: const Icon(Icons.arrow_drop_down),

      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB74D)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
      validator: validator,
    );
  }
  // ***************************************************************

  Widget _buildCheckboxField(
    String title,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return CheckboxListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.deepPurple,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple.shade700,
        ),
      ),
    );
  }

  // NOTE: This function is now redundant as we removed the pet list display.
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showAppBar = !widget.isModal;

    if (_currentUser == null) {
      if (showAppBar) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('My Pets'),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Please log in to manage your pet profiles.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          ),
        );
      } else {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Please log in to manage your pet profiles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
        );
      }
    }

    // MODIFIED: We only render the form content now.
    final Widget mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Keep the Cancel button, as it performs form cleanup
              ElevatedButton.icon(
                onPressed: _clearForm,
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                label: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
        // This Expanded widget now directly contains the form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildSectionTitle(
                    _editingPet == null
                        ? 'Register New Pet'
                        : 'Edit Pet Profile',
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.orange.shade100,
                          backgroundImage: _petProfileImageFile != null
                              ? FileImage(_petProfileImageFile!)
                                    as ImageProvider
                              : (_petProfileImageUrl != null &&
                                            _petProfileImageUrl!.isNotEmpty
                                        ? NetworkImage(_petProfileImageUrl!)
                                        : null)
                                    as ImageProvider?,
                          child:
                              _petProfileImageFile == null &&
                                  (_petProfileImageUrl == null ||
                                      _petProfileImageUrl!.isEmpty)
                              ? Icon(
                                  Icons.pets,
                                  size: 80,
                                  color: Colors.orange.shade700,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                              onPressed: () => _pickImage(
                                (file) => setState(() {
                                  _petProfileImageFile = file;
                                  _petProfileImageUrl = null;
                                }),
                                context,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _petNameController,
                    labelText: 'Pet Name',
                    icon: Icons.pets,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter pet name' : null,
                  ),
                  const SizedBox(height: 10),
                  // ***************************************************************
                  // Pet Type Dropdown: Functional, but 'Other' option is removed
                  // ***************************************************************
                  _buildDropdownField(
                    value: _selectedPetType,
                    items: _petTypes,
                    labelText: 'Pet Type',
                    icon: Icons.category,
                    onChanged: (String? newValue) {
                      setState(() {
                        // When pet type changes, reset breed and custom breed field
                        _selectedPetType = newValue;
                        _selectedPetBreed = null;
                        _customPetBreedController.clear();
                      });
                    },
                    allowOther: false, // Prevents 'Other' from appearing
                    validator: (value) =>
                        value == null ? 'Please select pet type' : null,
                  ),
                  // ***************************************************************
                  const SizedBox(height: 10),
                  // Pet Breed Dropdown: Functional and allows 'Other'
                  if (_selectedPetType != null)
                    _buildDropdownField(
                      value: _selectedPetBreed,
                      items: _availableBreeds[_selectedPetType] ?? [],
                      labelText: 'Pet Breed',
                      icon: Icons.merge_type,
                      onChanged: (String? newValue) {
                        setState(() {
                          // Clear custom breed if a non-Other breed is selected
                          if (newValue != 'Other') {
                            _customPetBreedController.clear();
                          }
                          _selectedPetBreed = newValue;
                        });
                      },
                      allowOther: true, // Pet Breed allows 'Other'
                      validator: (value) {
                        if (value == null) {
                          return 'Please select pet breed';
                        }
                        // Add validation for custom field when 'Other' is selected
                        if (value == 'Other' &&
                            _customPetBreedController.text.isEmpty) {
                          return 'Please specify the breed below';
                        }
                        return null;
                      },
                    )
                  else
                    // Placeholder/Hint if pet type is not selected
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.merge_type, color: Colors.grey.shade400),
                          const SizedBox(width: 15),
                          Text(
                            'Select Pet Type first to choose breed',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  // END OF MODIFIED PET BREED DROPDOWN FIELD
                  const SizedBox(height: 10),
                  // NEW: Conditional Custom Pet Breed Field
                  if (_selectedPetBreed == 'Other')
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 10.0,
                      ), // Padding adjusted for placement
                      child: _buildTextField(
                        controller: _customPetBreedController,
                        labelText: 'Specify Pet Breed',
                        icon: Icons.text_fields,
                        validator: (value) =>
                            value!.isEmpty ? 'Please specify the breed' : null,
                      ),
                    ),

                  _buildDropdownField(
                    value: _selectedGender,
                    items: _genders,
                    labelText: 'Pet Gender',
                    icon: Icons.transgender,
                    // Pet Gender is NOT disabled
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedGender = newValue;
                      });
                    },
                    allowOther: false, // No 'Other' for Gender
                    validator: (value) =>
                        value == null ? 'Please select pet gender' : null,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _petWeightController,
                    labelText: 'Pet Weight (kg)',
                    icon: Icons.monitor_weight,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isEmpty) return 'Please enter pet weight';
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildDateField(
                    context,
                    controller: _petBirthdateController,
                    labelText: 'Date of Birth',
                    icon: Icons.calendar_today,
                    validator: (value) =>
                        value!.isEmpty ? 'Please select pet birthdate' : null,
                  ),
                  const SizedBox(height: 10),
                  // ***************************************************************
                  // Cage Type Dropdown: Functional, but 'Other' option is removed
                  // ***************************************************************
                  _buildDropdownField(
                    value: _selectedCageType,
                    items: _cageTypes,
                    labelText: 'Cage Type',
                    icon: Icons.home,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCageType = newValue;
                      });
                    },
                    allowOther: false, // Prevents 'Other' from appearing
                    validator: (value) =>
                        value == null ? 'Please select cage type' : null,
                  ),
                  // ***************************************************************
                  const SizedBox(height: 20),
                  // Vaccination status banner (omitted for brevity)
                  Builder(
                    builder: (context) {
                      final bool isVaccinated =
                          (_vaccinationRecordImageFile != null) ||
                          (_vaccinationRecordImageUrl != null &&
                              _vaccinationRecordImageUrl!.isNotEmpty);
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isVaccinated ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isVaccinated ? Icons.verified : Icons.warning,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isVaccinated
                                  ? 'Vaccinated (Record Provided)'
                                  : 'Not Vaccinated (No Record)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  _buildSectionTitle('Vaccination Record (Optional)'),
                  const SizedBox(height: 10),
                  // Image upload section (omitted for brevity)
                  Center(
                    child: Column(
                      children: [
                        if (_vaccinationRecordImageFile != null)
                          Stack(
                            children: [
                              Container(
                                height: 150,
                                width: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                    image: FileImage(
                                      _vaccinationRecordImageFile!,
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 5,
                                right: 5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _vaccinationRecordImageFile = null;
                                        _vaccinationRecordImageUrl = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (_vaccinationRecordImageUrl != null &&
                            _vaccinationRecordImageUrl!.isNotEmpty)
                          Stack(
                            children: [
                              Container(
                                height: 150,
                                width: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      _vaccinationRecordImageUrl!,
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 5,
                                right: 5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _vaccinationRecordImageUrl = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          const Text('No vaccination record image selected.'),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(
                            (file) => setState(() {
                              _vaccinationRecordImageFile = file;
                              _vaccinationRecordImageUrl = null;
                            }),
                            context,
                          ),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Vaccination Record'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Feeding Details (Optional)'),
                  const SizedBox(height: 10),
                  // ***************************************************************
                  // Food Brand Dropdown: Functional, but 'Other' option is removed
                  // ***************************************************************
                  _buildDropdownField(
                    value: _selectedFoodBrand,
                    items: _foodBrands,
                    labelText: 'Preferred Food Brand',
                    icon: Icons.fastfood,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedFoodBrand = newValue;
                      });
                    },
                    allowOther: false, // Prevents 'Other' from appearing
                    validator: (value) =>
                        value == null ? 'Please select a food brand' : null,
                  ),
                  // ***************************************************************
                  const SizedBox(height: 10),
                  _buildCheckboxField(
                    'I will bring my pet\'s own food',
                    _bringOwnFood,
                    (bool? newValue) {
                      setState(() {
                        _bringOwnFood = newValue ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _numberOfMealsController,
                    labelText: 'Number of Meals per day',
                    icon: Icons.format_list_numbered,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isNotEmpty && double.tryParse(value) == null) {
                        return 'Please enter a valid number, or leave empty.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildCheckboxField('Morning Feeding', _morningFeeding, (
                    bool? newValue,
                  ) {
                    setState(() {
                      _morningFeeding = newValue!;
                    });
                  }),
                  if (_morningFeeding) ...[
                    _buildTimeField(
                      context,
                      _morningTimeController,
                      'Morning Time',
                      Icons.access_time,
                    ),
                    const SizedBox(height: 10),
                    _buildFoodGramsField(
                      controller: _morningFoodGramsController,
                      labelText: 'Morning Food Grams',
                      icon: Icons.scale,
                      validator: (value) {
                        if (value!.isNotEmpty &&
                            double.tryParse(value) == null) {
                          return 'Please enter a valid number.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildCheckboxField('Afternoon Feeding', _afternoonFeeding, (
                    bool? newValue,
                  ) {
                    setState(() {
                      _afternoonFeeding = newValue!;
                    });
                  }),
                  if (_afternoonFeeding) ...[
                    _buildTimeField(
                      context,
                      _afternoonTimeController,
                      'Afternoon Time',
                      Icons.access_time,
                    ),
                    const SizedBox(height: 10),
                    _buildFoodGramsField(
                      controller: _afternoonFoodGramsController,
                      labelText: 'Afternoon Food Grams',
                      icon: Icons.scale,
                      validator: (value) {
                        if (value!.isNotEmpty &&
                            double.tryParse(value) == null) {
                          return 'Please enter a valid number.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildCheckboxField('Evening Feeding', _eveningFeeding, (
                    bool? newValue,
                  ) {
                    setState(() {
                      _eveningFeeding = newValue!;
                    });
                  }),
                  if (_eveningFeeding) ...[
                    _buildTimeField(
                      context,
                      _eveningTimeController,
                      'Evening Time',
                      Icons.access_time,
                    ),
                    const SizedBox(height: 10),
                    _buildFoodGramsField(
                      controller: _eveningFoodGramsController,
                      labelText: 'Evening Food Grams',
                      icon: Icons.scale,
                      validator: (value) {
                        if (value!.isNotEmpty &&
                            double.tryParse(value) == null) {
                          return 'Please enter a valid number.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 30),
                  Center(
                    child: _isLoadingForm
                        ? const CircularProgressIndicator(
                            color: Colors.deepPurple,
                          )
                        : ElevatedButton(
                            onPressed: _submitPetForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 50,
                                vertical: 15,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _editingPet == null
                                  ? 'Register Pet'
                                  : 'Update Pet',
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Register Pet'), // Updated title to reflect change
          backgroundColor: const Color(0xFFFFB64A),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: mainContent,
      );
    } else {
      return mainContent;
    }
  }
}
