import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseUIAuth.configureProviders([EmailAuthProvider()]);
  runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider(),)
      ],
      child: const BookatApp(),
    ),
  );
}

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  User? get user => _user;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } 
    catch (e) {
      throw Exception('Error signing in: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  bool get isLoggedIn => _user != null;

}

class UserProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _user;
  String _firstName = '';
  String _lastName = '';
  String get firstName => _firstName;
  String get lastName => _lastName;

  UserProvider() {
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _fetchUserName(_user!.uid);
      notifyListeners();
    }
  }

  Future<void> _fetchUserName(String? uid) async {
    try {
      DocumentSnapshot userDoc = await _db.collection('Users').doc(uid).get();
      if (userDoc.exists) {
        _firstName = userDoc['firstName'] ?? '';
        _lastName = userDoc['lastName'] ?? '';
        notifyListeners(); 
      }
    } 
    catch (e) {
      print("Error fetching user data: $e");
    }
  }
}

class SettingsProvider with ChangeNotifier {
  bool _isDarkMode = false;
  double _textSize = 16.0;

  bool get isDarkMode => _isDarkMode;
  double get textSize => _textSize;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setTextSize(double newSize) {
    _textSize = newSize;
    notifyListeners();
  }
}

class BookatApp extends StatelessWidget {
  const BookatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bookat',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key}); 

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final db = FirebaseFirestore.instance;
    final String firstName = userProvider._firstName;
    final String lastName = userProvider._lastName;


    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookat Home Page'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              //Takes user to Search Page
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const SearchPage()));
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green,
              ),
              child: Text(
                'Navigator',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home Page'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You are currently on the Home Page')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Your Library'),
              onTap: () {
                if (authProvider.isLoggedIn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LibraryPage()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please log in first')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                if (authProvider.isLoggedIn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please log in first')),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (authProvider.isLoggedIn) ...[
              // Display logged-in user's first and last name
              Text(
                'Hi $firstName $lastName!\n'
                'Welcome to Bookat, the ebook catalog app!',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ] 
            else ...[
              Text(
                'Welcome to Bookat, the ebook catalog app!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 20),
            // Login and Register buttons
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Login Button
                // if user is logged in, the login button is enabled, 
                // else the button is disabled.
                ElevatedButton(
                  onPressed: !authProvider.isLoggedIn ? () {
                    // Goes to Login Page
                    Navigator.push(context,
                      MaterialPageRoute(
                        builder: (context) => LoginPage()));
                  } : null,
                  child: Text('Login'),
                ),
                SizedBox(width:20),
                Text('or'),
                SizedBox(width: 20),
                // Register Button
                // if user is logged in, the register button is enabled, 
                // else the button is disabled.
                ElevatedButton(
                  onPressed: !authProvider.isLoggedIn ? () {
                    Navigator.push(context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage()));
                  } : null,
                  child: Text('Register'),
                ),
              ],
            ),
            SizedBox(height: 20),
            // User's Most Recent Books
            // if the user is logged in, their most recent books are displayed
            Text(
              'Your Most Recent Books',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 50),
            Container(
              margin: const EdgeInsets.all(10.0),
              height: 200.0,
              // builds snapshot stream of the user's most recent
              // books in descending order
              child: authProvider.isLoggedIn ?
                StreamBuilder<DocumentSnapshot>(
                  stream: db.collection('user_books').doc(authProvider.user?.uid).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      debugPrint('Error in user_books stream: ${snapshot.error}');
                      return const Center(child: Text('Error fetching data'));
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(child: Text('No books found'));
                    }

                    // Casting snapshot.data().data() to a Map<String, dynamic> to access 'checkedOutBooks'
                    Map<String, dynamic>? booksMap = 
                      (snapshot.data!.data() as Map<String, dynamic>)['checkedOutBooks'] as Map<String, dynamic>?;

                    if (booksMap == null || booksMap.isEmpty) {
                      return const Center(child: Text('No books found'));
                    }

                    // Convert map to list of books and sort by checkedOutDate
                    List<Map<String, dynamic>> booksList = booksMap.values
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
                    booksList.sort((a, b) => (b['checkedOutDate'] as Timestamp)
                      .compareTo(a['checkedOutDate'] as Timestamp));

                    return ListView.builder(
                      itemCount: booksList.length,
                      itemBuilder: (context, index) {
                        var book = booksList[index];
                        int bookRank = index + 1;

                        return Card(
                          elevation: 2.0,
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: Text('$bookRank'), // Book ranking
                            title: Text(book['title'] ?? 'No Title'),
                            subtitle: Text('By ${book['author'] ?? 'Unknown Author'}'),
                            onTap: () {
                              // Navigate to the book's page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookPage(
                                    bookId: book['bookId'],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                )

              : const Center(
                  child: Text(
                    'Please log in to view your books.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
            ),
            SizedBox(height: 10),
            // Top 10 Books text
            Text(
              'Top 10 Books',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            // SizedBox(height: 100),
            // Top 10 Books Container widget
            Container(
              margin: const EdgeInsets.all(10.0),
              height: 200.0,
              // builds snapshot stream of the top 10 books 
              // by 'Times Checked Out' field in descending order
              child: StreamBuilder<QuerySnapshot>(
                stream: db.collection('bookat')
                    .orderBy('Times Checked Out', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    debugPrint('Error in search results stream: '
                    '${snapshot.error}');
                    return const Center(child: Text('Error fetching data'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No popular ebooks found'));
                  }
                  // List of 
                  var ebooks = snapshot.data!.docs;
                  // returns ListView of the Top 10 Books 
                  // by Times Checked Out in descending order
                  return ListView.builder(
                    itemCount: ebooks.length,
                    itemBuilder: (context, index) {
                      final ebook = ebooks[index];
                      int bookRank = index;
                      // returns the Card widget for each book in the ListView
                      return Card(
                        elevation: 2.0,
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          leading: Text('${++bookRank}'), // Book ranking
                          title: Text(ebook['Title'] ?? 'No Title'),
                          subtitle: Text(ebook['Author'] ?? 'Unknown Author'),
                          onTap: () {
                            // Navigate to that ebook's Book Page
                            // uses ebook.id for the document's ID 
                            // for the bookId parameter
                            Navigator.push(context,
                              MaterialPageRoute(
                                builder: (context) => BookPage(
                                  bookId: ebook.id)));
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // About Page Button
            FilledButton( 
              onPressed: () {
                // Takes you to the About Page
                Navigator.push(context,
                  MaterialPageRoute(
                    builder: (context) => const AboutPage()));
              },
              child: const Text('About Page'),
            ),
            SizedBox(height: 10),
          ]    
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget{
  const AboutPage({super.key});
  final String date = '11/23/2024';
  final String description = 
    "Hi, welcome to Bookat, the ebook catalog app.On Bookat, you can browse a "
    "collection of different books from different genres, authors, and titles. "
    "This app's purpose is to let you, dear user, have a digital library of "
    "your own!";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About Page'),
      ),
      body: Column(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(25),
              child: RichText(text: TextSpan(
                  text: description,
                  style: TextStyle(
                    fontSize: 20
                  ),
                )
              ),
            ),
          ),
          
          SizedBox(height: 10),
          Text(
            'Version: O.1',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold, 
            ),
          ),
          Text(
            'Last updated: $date',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold, 
            ),
          ),
          Text(
            'Developed by Stephen Simonsen',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold, 
            ),
          ),
        ],
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPage();
}

class _SearchPage extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Query _getSearchQuery() {
    String queryText = _searchController.text.toLowerCase();
    if (queryText.isEmpty) {
      return _db.collection('bookat')
                .orderBy('Title');  // Show all books when search is empty
    } 
    else {
      return _db.collection('bookat')
                .where('searchInfo', arrayContains: queryText);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Ebooks'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by title or author',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _getSearchQuery().snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                var ebooks = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: ebooks.length,
                  itemBuilder: (context, index) {
                    var ebook = ebooks[index];
                    return ListTile(
                      title: Text(ebook['Title']),
                      subtitle: Text(ebook['Author']),
                      onTap: () {
                        // Navigate to ebook's Book Page
                        Navigator.push(context,
                          MaterialPageRoute(
                            builder: (context) => BookPage(bookId: ebook.id)));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final providers = [EmailAuthProvider()];
    
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator()
          );
        }
        if (snapshot.hasData) {
          return HomePage();
        }
        return SignInScreen(
          providers: providers,
          actions: [
            AuthStateChangeAction<SignedIn>((context, state) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomePage()),
              );
            }),
          ],
        );
      },
    );
  }
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator()
          );
        }
        if (snapshot.hasData) {
          return HomePage();
        }
        return RegisterScreen(
          actions: [
            AuthStateChangeAction<SignedIn>((context, state) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomePage()),
              );
            }),
          ],
        );
      }
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _logout(AuthProvider authProvider) async {
    await authProvider.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'First Name: ${userProvider.firstName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Last Name: ${userProvider.lastName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),);
              },
              child: const Text('Settings'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LibraryPage()),
                );
              },
              child: const Text('Your Library'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                _logout(authProvider);
                // Navigate to the Login Page or any other screen
                Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => const HomePage()),);
              },
              child: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}

class LibraryPage extends StatefulWidget {

  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _sortOption = 'Alphabetical';

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final FirebaseFirestore db = FirebaseFirestore.instance;

    if (!authProvider.isLoggedIn) {
      return Scaffold(
        body: Column(
          children: [
            Center(
              child: Text('Please log in to access your library'),
            ),
            ElevatedButton(
              onPressed: !authProvider.isLoggedIn ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
              : null,
              child: const Text('Login'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library'),
        actions: <Widget>[
          DropdownButton<String>(
            value: _sortOption,
            items: <String>['Alphabetical', 'Most Popular', 'Available Copies']
                .map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _sortOption = newValue!;
              });
            },
          ),
        ],
      ),
      body: 
        StreamBuilder<DocumentSnapshot>(
          stream: db.collection('user_books').doc(authProvider.user?.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              debugPrint('Error in user_books stream: ${snapshot.error}');
              return const Center(child: Text('Error fetching data'));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('No books found'));
            }

            // Casting snapshot.data().data() to a Map<String, dynamic> to access 'checkedOutBooks'
            Map<String, dynamic>? booksMap = 
              (snapshot.data!.data() as Map<String, dynamic>)['checkedOutBooks'] as Map<String, dynamic>?;

            if (booksMap == null || booksMap.isEmpty) {
              return const Center(child: Text('No books found'));
            }

            // Convert map to list of books 
            List<Map<String, dynamic>> booksList = booksMap.values
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            // Sort list of books by checkedOutDate
            booksList.sort((a, b) => (b['checkedOutDate'] as Timestamp)
              .compareTo(a['checkedOutDate'] as Timestamp));
          
          return ListView.builder(
            itemCount: booksList.length,
            itemBuilder: (context, index) {
              final book = booksList[index];
              return ListTile(
                title: Text(book['title'] ?? 'No Title'),
                subtitle: Text(book['author'] ?? 'Unknown Author'),
                trailing: Text(book['genre'] ?? 'Unknown Genre'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookPage(bookId: book['bookId']),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _getSortField() {
    switch (_sortOption) {
      case 'Most Popular':
        return 'timesCheckedOut';
      case 'Available Copies':
        return 'availableCopies';
      case 'Alphabetical':
      default:
        return 'title';
    }
  }
}

class BookPage extends StatefulWidget {
  final String bookId;
  const BookPage({super.key, required this.bookId});

  @override
  State<BookPage> createState() => _BookPage();
}

class _BookPage extends State<BookPage> {
  bool isCheckedOut = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  @override
  void initState() {
    final String bookId = widget.bookId;
    super.initState();
    _getBookData(context, bookId);
  }

  // Function to fetch the book data
  Future<void> _getBookData(BuildContext context, String bookId) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Get the user's checked out books document from Firestore
        DocumentSnapshot userBooksSnapshot = await _db.collection('user_books')
            .doc(user.uid).get();

        if (userBooksSnapshot.exists) {
          var checkedOutBooksData = userBooksSnapshot.data() as Map<String, dynamic>;
          if (checkedOutBooksData.containsKey('checkedOutBooks')) {
            Map<String, dynamic> checkedOutBooks = checkedOutBooksData['checkedOutBooks'];
            if (checkedOutBooks.containsKey(bookId)) {
              setState(() {
                isCheckedOut = true;
              });
            }
          }
        }
      }
    } 
    catch (e) {
      setState(() {
        print("Error fetching checked out book: $e");
      });
    }
  }

  Future<void> checkoutBook(BuildContext context, String bookId) async {
    // Get the current user
    User? user = _auth.currentUser;

    if (user != null) {
      try {
        // Get the book data from the 'bookat' collection
        DocumentSnapshot bookSnapshot = await _db.collection('bookat')
          .doc(bookId)
          .get();

        if (bookSnapshot.exists) {
          var book = bookSnapshot.data() as Map<String, dynamic>;

          // Add the book to the 'user_books' collection under 
          // 'checkedOutBooks' field as a map of maps
          await FirebaseFirestore.instance.collection('user_books')
            .doc(user.uid)
            .set({
              'checkedOutBooks': {
                bookId: {
                  'title': book['Title'] ?? 'Unknown Title',
                  'author': book['Author'] ?? 'Unknown Author',
                  'bookId': bookId,
                  'genre': book['Genre'] ?? 'Unkown Genre',
                  // Add timestamp for when the book was checked out
                  'checkedOutDate': FieldValue.serverTimestamp(), 
                }
              }
            }, SetOptions(merge: true));

          // Update the book's 'timesCheckedOut' field
          await FirebaseFirestore.instance.collection('bookat').doc(bookId).update({
            'Times Checked Out': (book['Times Checked Out'] ?? 0) + 1,
          });

          if (context.mounted) {
            // Show a success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Book checked out successfully!'))
            );
          }
        }
      } 
      catch (e) {
        if (context.mounted) {
          // Handle any errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to checkout book: $e')));
          }
        }
      } 
  }

  Future<void> returnBook(BuildContext context, String bookId) async {
  // Get the current user
  User? user = _auth.currentUser;

  if (user != null) {
    try {
      // Fetch the current user_books document
      DocumentReference userBooksRef = _db.collection('user_books').doc(user.uid);
      DocumentSnapshot userBooksSnapshot = await userBooksRef.get();

      if (userBooksSnapshot.exists) {
        // Check if the `checkedOutBooks` field exists
        var userBooksData = userBooksSnapshot.data() as Map<String, dynamic>?;
        if (userBooksData != null && userBooksData.containsKey('checkedOutBooks')) {
          var checkedOutBooks = userBooksData['checkedOutBooks'] as Map<String, dynamic>;

          if (checkedOutBooks.containsKey(bookId)) {
            // Remove the book from `checkedOutBooks`
            checkedOutBooks.remove(bookId);

            // Update the Firestore document with the modified `checkedOutBooks` map
            await userBooksRef.update({'checkedOutBooks': checkedOutBooks});

            if (context.mounted) {
              // Show a success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Book returned successfully!'))
              );
            }
          } else {
            if (context.mounted) {
              // If the book is not found in checkedOutBooks
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Book not found in checked out books!'))
              );
            }
          }
        } else {
          if (context.mounted) {
            // If no checkedOutBooks field
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No books checked out!'))
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        // Handle any errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to return book: $e'))
        );
      }
    }
  } else {
    if (context.mounted) {
      // If no user is logged in
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to log in to return a book')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookat'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              //Takes user to Search Page
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (context) => const SearchPage()));
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green,
              ),
              child: Text(
                'Navigator',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home Page'),
              onTap: () {
                // Takes user to Home Page
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (context) => const HomePage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Your Library'),
              onTap: () {
                // Takes user to Library Page
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (context) => const LibraryPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                //Take user to Settings Page
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsPage()));
              },
            ),
          ],
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _db.collection('bookat').doc(widget.bookId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching book details'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Book not found'));
          }

          final book = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title of the book if Title field is nonnull,
                // else the text is 'No Title'
                Text(
                    book['Title'] ?? 'No Title',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold
                    )
                ),
                const SizedBox(height: 8.0),
                // Author of the book if Author field is nonnull,
                // else the text is 'Unknown'
                RichText(
                  text: TextSpan(
                    text: 'Author: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    children: <TextSpan>[
                      TextSpan(text: '${book['Author'] ?? 'Unknown'}',
                        style: TextStyle(fontWeight: FontWeight.normal)),
                      ]
                  )
                ),
                const SizedBox(height: 8.0),
                // Genre of the book if Genre field is nonnull,
                // else the text is 'Unknown'
                RichText(
                  text: TextSpan(
                    text: 'Genre: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    children: <TextSpan>[
                      TextSpan(text: '${book['Genre'] ?? 'Unknown'}',
                        style: TextStyle(fontWeight: FontWeight.normal)),
                      ]
                  )
                ),
                const SizedBox(height: 8.0),
                // Description of the book if Description field is nonnull,
                // else the text is 'Unknown'
                RichText(
                  text: TextSpan(
                    text: 'Description: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    children: <TextSpan>[
                      TextSpan(text: '${book['Description'] ?? 'Unknown'}',
                        style: TextStyle(fontWeight: FontWeight.normal)),
                      ]
                  )
                ),
                SizedBox(height: 10),
                // Display buttons depending on whether the book is checked out
                isCheckedOut ?
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Handle reading book
                        Navigator.push(context,
                            MaterialPageRoute(
                                builder: (context) => ReadPage(
                                  bookId: widget.bookId,
                                  bookTitle: book['Title'],
                                )));
                      },
                      child: const Text('Read'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        // Handle returning book
                        returnBook(context, widget.bookId);
                      },
                      child: const Text('Return Book'),
                    ),
                  ],
                ) :
                ElevatedButton(
                  onPressed: () {
                    if (_auth.currentUser != null) {
                      // Checkout the book when the user clicks the button
                      checkoutBook(context, widget.bookId);
                    }
                    else {
                      // If no user is logged in
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You need to log in to checkout a book'))
                      );
                    }
                  },
                  child: const Text('Checkout Book'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ReadPage extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  const ReadPage({super.key, required this.bookId, required this.bookTitle});

  @override
  State<ReadPage> createState() => _ReadPage();
}

class _ReadPage extends State<ReadPage> {
  static const String _gitHubUsername = 'sycsen';
  static const String _repository = 'bookat.github.io';
  static const String _extension = 'epub';
  //final FirebaseAuth _auth = FirebaseAuth.instance;
  //final FirebaseFirestore _db = FirebaseFirestore.instance;
  late EpubController _epubController;
  bool isLoading = true;

  @override
  void initState() {
    final String bookName = widget.bookId;
    final String epubUrl = 
      'https://$_gitHubUsername.github.io/$_repository/$bookName.$_extension';
    super.initState();
    _loadEpubFromUrl(epubUrl);
  }
  // Loading raw url of epub file into the _epubController;
  Future<void> _loadEpubFromUrl(String url) async {
    try {
      // Send a GET request to the provided URL
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // Load the EPUB into EpubController
        setState(() {
          _epubController = EpubController(
            document: EpubReader.readBook(response.bodyBytes),
          );
          isLoading = false; // Stop loading
        });
      } 
      else {
        throw Exception("Failed to load the EPUB file");
      }
    } 
    catch (e) {
      print("Error: $e");
    }
  }

  @override
  void dispose() {
    _epubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Home',
            onPressed: () {
              //Takes user to Search Page
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const HomePage()));
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: EpubViewTableOfContents(
          controller: _epubController,
        ),
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator())
        : EpubView(controller: _epubController),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    // Dispose controllers
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _db.collection('Users').doc(user.uid).get();
      if (userDoc.exists) {
        _firstNameController.text = userDoc['firstName'] ?? '';
        _lastNameController.text = userDoc['lastName'] ?? '';
        _emailController.text = userDoc['email'] ?? '';
      }
      else {
        final data = {"email": user.email, 'firstName': '', 'lastName': ''};
        _db.collection('Users').doc(user.uid).set(data, SetOptions(merge: true));
        _firstNameController.text = userDoc['firstName'] ?? '';
        _lastNameController.text = userDoc['lastName'] ?? '';
        _emailController.text = userDoc['email'] ?? '';
      }
    }
  }

  void _updateFirstName() {
    User? user = _auth.currentUser;
    if (user != null) {
      try {

        _db.collection('Users')
          .doc(user.uid)
          .update({'firstName': _firstNameController.text});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('First name updated successfully')),
        );
      } 
      catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update first name: $e')),
        );
      }
    }
    else {
      // If no user is logged in
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to update first name'))
      );
    }
  }

  void _updateLastName() {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        _db.collection('Users').doc(user.uid).update({'firstName': _firstNameController.text});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('First name updated successfully')),
        );
      } 
      catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update first name: $e')),
        );
      }
    }
    else {
      // If no user is logged in
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to update last name'))
      );
    }
  }

  void _updateEmail() {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        user.verifyBeforeUpdateEmail(_emailController.text);
        _db.collection('Users').doc(user.uid).update({'email': _emailController.text});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update email: $e')),
        );
      }
    }
    else {
      // If no user is logged in
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to update email'))
      );
    }
  }

  void _updatePassword() {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        user.updatePassword(_passwordController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update password: $e')),
        );
      }
    }
    else {
      // If no user is logged in
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to update email'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SettingsProvider>(
      create: (_) => SettingsProvider(),
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Settings'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  TextField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _updateFirstName,
                    child: const Text('Update first name'),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _updateLastName,
                    child: const Text('Update Last name'),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _updateEmail,
                    child: const Text('Update Email'),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _updatePassword,
                    child: const Text('Update Password'),
                  ),
                  const SizedBox(height: 32.0),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: settingsProvider.isDarkMode,
                    onChanged: (value) {
                      settingsProvider.toggleTheme();
                    },
                  ),
                  const SizedBox(height: 16.0),
                  ListTile(
                    title: const Text('Text Size'),
                    subtitle: Slider(
                      value: settingsProvider.textSize,
                      min: 12.0,
                      max: 24.0,
                      onChanged: (value) {
                        settingsProvider.setTextSize(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* //scrap code cuz firebase_ui_auth already does these jobs
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPage();
}

class _ForgotPasswordPage extends State<ForgotPasswordPage> {
  final GlobalKey<FormState> _forgotPasswordFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
      ),
      body: Form(
        key: _forgotPasswordFormKey,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Email',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (String? value) {
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  else if (!emailRegex.hasMatch(value)) {
                    return 'Enter a valid email';
                  }
                  else {
                    return null;
                  }
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'New Password',
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  else if (value.length < 6) {
                    return 'Password must be at least 8 characters';
                  }
                  else {
                    return null;
                  }
                },
              ),
              SizedBox(height: 5),
              FilledButton(
                onPressed: () {
                  if (_forgotPasswordFormKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Confirming password')));
                  }
                },
                child: Text('Submit New Password')
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/
