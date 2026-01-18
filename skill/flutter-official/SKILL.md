# Flutter & Dart Official Development Standards

> **Sources**: This skill contains ONLY content from official authoritative sources:
> - [Effective Dart](https://dart.dev/effective-dart) — Official Dart style guide
> - [Flutter App Architecture](https://docs.flutter.dev/app-architecture) — Official architecture guide
> - [BLoC Library](https://bloclibrary.dev) — Official BLoC documentation
> - [Riverpod](https://riverpod.dev) — Official Riverpod documentation
> - [very_good_analysis](https://github.com/VeryGoodOpenSource/very_good_analysis) — Industry-standard linting

---

## Table of Contents

1. [Effective Dart: Style](#1-effective-dart-style)
2. [Effective Dart: Usage](#2-effective-dart-usage)
3. [Effective Dart: Design](#3-effective-dart-design)
4. [Flutter App Architecture](#4-flutter-app-architecture)
5. [BLoC Pattern](#5-bloc-pattern)
6. [Riverpod State Management](#6-riverpod-state-management)
7. [Linting & Analysis](#7-linting--analysis)
8. [Testing](#8-testing)

---

## 1. Effective Dart: Style

### 1.1 Identifiers

#### DO use `UpperCamelCase` for types and extensions
```dart
// GOOD
class SliderMenu { ... }
class HttpRequest { ... }
extension MyFancyList<T> on List<T> { ... }
typedef Predicate<T> = bool Function(T value);
mixin Cloneable<T> { ... }
```

#### DO use `lowercase_with_underscores` for packages, directories, and source files
```dart
// GOOD
my_package
└─ lib
   └─ file_system.dart
   └─ slider_menu.dart

// BAD
mypackage
└─ lib
   └─ SliderMenu.dart
```

#### DO use `lowerCamelCase` for variables, parameters, and named parameters
```dart
// GOOD
var count = 3;
HttpRequest httpRequest;
void align(bool clearItems) { ... }

// BAD
var COUNT = 3;
HttpRequest HTTPRequest;
void align(bool clear_items) { ... }
```

#### DO use `lowerCamelCase` for constant names
```dart
// GOOD
const pi = 3.14;
const defaultTimeout = 1000;
final urlScheme = RegExp('^([a-z]+):');

// BAD
const PI = 3.14;
const kDefaultTimeout = 1000;  // No "k" prefix!
```

#### DO capitalize acronyms and abbreviations longer than two letters like words
```dart
// GOOD
class HttpConnection { }
class DBIOPort { }
class TVVcr { }
class MrRogers { }
var httpRequest = ...
var uiHandler = ...
var userId = ...
Id id;

// BAD
class HTTPConnection { }
class DbIoPort { }
class TvVcr { }
class MRRogers { }
var hTTPRequest = ...
var uIHandler = ...
var userID = ...
ID iD;
```

#### DO use `_`, `__`, etc. for unused callback parameters
```dart
// GOOD
futureOfVoid.then((_) {
  print('Operation complete.');
});
```

#### DON'T use prefix letters
```dart
// GOOD
defaultTimeout

// BAD
kDefaultTimeout  // No "k" prefix
mPosition        // No "m" for member
```

#### DON'T explicitly name libraries
```dart
// BAD
library my_library;

// GOOD - Just omit the library directive entirely
```

### 1.2 Ordering

#### DO place `dart:` imports before other imports
```dart
// GOOD
import 'dart:async';
import 'dart:html';

import 'package:bar/bar.dart';
import 'package:foo/foo.dart';
```

#### DO place `package:` imports before relative imports
```dart
// GOOD
import 'package:bar/bar.dart';
import 'package:foo/foo.dart';

import 'util.dart';
```

#### DO sort sections alphabetically
```dart
// GOOD
import 'package:bar/bar.dart';
import 'package:foo/foo.dart';

import 'foo.dart';
import 'foo/foo.dart';
```

### 1.3 Formatting

#### DO format your code using `dart format`
```bash
dart format .
```

#### AVOID lines longer than 80 characters
Exception: URIs, file paths, and multi-line strings.

#### DO use curly braces for all flow control statements
```dart
// GOOD
if (isWeekDay) {
  print('Bike to work!');
} else {
  print('Go dancing or read a book!');
}

// EXCEPTION: Simple if with no else on one line is OK
if (arg == null) return defaultValue;
```

---

## 2. Effective Dart: Usage

### 2.1 Libraries

#### DO use strings in `part of` directives
```dart
// GOOD
part of '../../my_library.dart';

// BAD
part of my_library;
```

#### DON'T import libraries inside `src/`
```dart
// BAD
import 'package:some_package/src/private_file.dart';

// GOOD
import 'package:some_package/some_package.dart';
```

#### DON'T allow import paths to reach into or out of `lib/`
```dart
// BAD - From web/main.dart
import '../lib/api.dart';

// GOOD
import 'package:my_package/api.dart';
```

#### PREFER relative import paths within `lib/`
```dart
// GOOD - From lib/src/utils/helpers.dart
import '../models/user.dart';

// ACCEPTABLE but less preferred
import 'package:my_app/models/user.dart';
```

### 2.2 Null Safety

#### DON'T explicitly initialize variables to `null`
```dart
// GOOD
Item? bestDeal;

// BAD
Item? bestDeal = null;
```

#### DON'T use explicit defaults of `null`
```dart
// GOOD
void error([String? message]) { ... }

// BAD
void error([String? message = null]) { ... }
```

#### DON'T use `true` or `false` in equality operations
```dart
// GOOD
if (nonNullableBool) { ... }
if (!nonNullableBool) { ... }

// BAD
if (nonNullableBool == true) { ... }
if (nonNullableBool == false) { ... }
```

#### AVOID `late` variables if you need to check initialization
```dart
// BAD
late String? _userInput;
bool _hasUserInput = false;

void setUserInput(String value) {
  _userInput = value;
  _hasUserInput = true;
}

// GOOD
String? _userInput;

void setUserInput(String value) {
  _userInput = value;
}

String? get userInput => _userInput;
```

### 2.3 Strings

#### DO use adjacent strings to concatenate literals
```dart
// GOOD
final message = 'This is a very long string that '
    'spans multiple lines.';

// BAD
final message = 'This is a very long string that ' +
    'spans multiple lines.';
```

#### PREFER using interpolation
```dart
// GOOD
'Hello, $name! You are ${year - birthYear} years old.';

// BAD
'Hello, ' + name + '! You are ' + (year - birthYear).toString() + ' years old.';
```

#### AVOID using curly braces when not needed
```dart
// GOOD
var greeting = 'Hi, $name!';

// BAD
var greeting = 'Hi, ${name}!';
```

### 2.4 Collections

#### DO use collection literals when possible
```dart
// GOOD
var addresses = <String, Address>{};
var counts = <int>[];
var uniqueNames = <String>{};

// BAD
var addresses = Map<String, Address>();
var counts = List<int>();
var uniqueNames = Set<String>();
```

#### DON'T use `.length` to check if a collection is empty
```dart
// GOOD
if (lunchBox.isEmpty) return 'Eat out!';
if (words.isNotEmpty) return words.join(' ');

// BAD
if (lunchBox.length == 0) return 'Eat out!';
if (words.length > 0) return words.join(' ');
```

#### AVOID using `Iterable.forEach()` with function literals
```dart
// GOOD
for (final person in people) {
  print(person.name);
}

// BAD
people.forEach((person) {
  print(person.name);
});
```

#### DON'T use `List.from()` unless intending to change the type
```dart
// GOOD
var copy1 = iterable.toList();
var copy2 = [...iterable];

// BAD (unless you need to upcast)
var copy = List<Base>.from(derivedList);
```

#### DO use `whereType()` to filter by type
```dart
// GOOD
var objects = [1, 'two', 3, 'four'];
var ints = objects.whereType<int>();

// BAD
var ints = objects.where((e) => e is int).cast<int>();
```

### 2.5 Functions

#### DO use a function declaration to bind a function to a name
```dart
// GOOD
void main() {
  void localFunction() { ... }
}

// BAD
void main() {
  var localFunction = () { ... };
}
```

#### DON'T create a lambda when a tear-off will do
```dart
// GOOD
var charCodes = [68, 97, 114, 116];
var buffer = StringBuffer();
charCodes.forEach(buffer.writeCharCode);
names.removeWhere(googler.isGoogler);

// BAD
charCodes.forEach((code) {
  buffer.writeCharCode(code);
});
names.removeWhere((name) => googler.isGoogler(name));
```

### 2.6 Variables

#### DO follow consistent naming for local variables
```dart
// BAD - Hungarian notation
final String sName = 'John';
final int iAge = 25;

// GOOD
final name = 'John';
final age = 25;
```

#### DON'T use `dynamic` unless you want to disable static checks
```dart
// GOOD - Use Object? for truly unknown types
void log(Object? object) {
  print(object);
}

// BAD - Avoids all type checking
void log(dynamic object) {
  print(object);
}
```

### 2.7 Members

#### DON'T wrap a field in a getter and setter unnecessarily
```dart
// GOOD
class Box {
  Object? contents;
}

// BAD
class Box {
  Object? _contents;
  Object? get contents => _contents;
  set contents(Object? value) {
    _contents = value;
  }
}
```

#### PREFER using `final` for read-only properties
```dart
// GOOD
class Box {
  final Object? contents;
  Box(this.contents);
}
```

#### CONSIDER using `=>` for simple members
```dart
// GOOD
double get area => (right - left) * (bottom - top);
String get name => '$firstName $lastName';

bool isReady(num time) => minTime == null || minTime! <= time;
```

#### DON'T use `this.` except to redirect to a named constructor
```dart
// GOOD
class Box {
  Object? value;
  
  void clear() {
    update(null);
  }
  
  void update(Object? value) {
    this.value = value;  // OK - parameter shadows field
  }
}

// BAD
class Box {
  Object? value;
  
  void clear() {
    this.update(null);  // Unnecessary this.
  }
}
```

### 2.8 Constructors

#### DO use initializing formals when possible
```dart
// GOOD
class Point {
  double x, y;
  Point(this.x, this.y);
}

// BAD
class Point {
  double x, y;
  Point(double x, double y) {
    this.x = x;
    this.y = y;
  }
}
```

#### DO use `;` instead of `{}` for empty constructor bodies
```dart
// GOOD
class Point {
  double x, y;
  Point(this.x, this.y);
}

// BAD
class Point {
  double x, y;
  Point(this.x, this.y) {}
}
```

#### DON'T use `new`
```dart
// GOOD
var point = Point(1, 2);

// BAD
var point = new Point(1, 2);
```

#### DON'T redundantly use `const`
```dart
// GOOD
const primaryColors = [
  Color('red', [255, 0, 0]),
  Color('green', [0, 255, 0]),
  Color('blue', [0, 0, 255]),
];

// BAD
const primaryColors = const [
  const Color('red', const [255, 0, 0]),
  const Color('green', const [0, 255, 0]),
  const Color('blue', const [0, 0, 255]),
];
```

### 2.9 Error Handling

#### AVOID catches without `on` clauses
```dart
// GOOD
try {
  somethingRisky();
} on FormatException catch (e) {
  handleFormatException(e);
} on IOException catch (e) {
  handleIOException(e);
}

// BAD
try {
  somethingRisky();
} catch (e) {
  // What are we catching?
}
```

#### DON'T discard errors from catches without `on` clauses
```dart
// GOOD
try {
  somethingRisky();
} catch (e) {
  log(e);  // At minimum, log it
  rethrow;
}

// BAD
try {
  somethingRisky();
} catch (e) {
  // Silently swallowed!
}
```

#### DO throw objects that implement `Error` for programmatic errors
```dart
// GOOD - Programmatic error (bug in code)
if (index < 0 || index >= length) {
  throw RangeError.range(index, 0, length - 1);
}

// GOOD - Runtime error (external failure)
throw FormatException('Invalid input: $input');
```

#### DON'T explicitly catch `Error` or types that implement it
```dart
// BAD
try {
  somethingRisky();
} on ArgumentError catch (e) {
  // Don't catch programming errors!
}

// GOOD - Let errors propagate and fix the bug
```

#### DO use `rethrow` to rethrow a caught exception
```dart
// GOOD
try {
  somethingRisky();
} catch (e) {
  log(e);
  rethrow;
}

// BAD
try {
  somethingRisky();
} catch (e) {
  log(e);
  throw e;  // Loses stack trace
}
```

### 2.10 Async

#### PREFER async/await over raw futures
```dart
// GOOD
Future<int> countActivePlayers(String teamName) async {
  try {
    var team = await downloadTeam(teamName);
    if (team == null) return 0;
    
    var players = await team.roster;
    return players.where((player) => player.isActive).length;
  } catch (e) {
    log.error(e);
    return 0;
  }
}

// BAD - Harder to read and maintain
Future<int> countActivePlayers(String teamName) {
  return downloadTeam(teamName).then((team) {
    if (team == null) return Future.value(0);
    
    return team.roster.then((players) {
      return players.where((player) => player.isActive).length;
    });
  }).catchError((e) {
    log.error(e);
    return 0;
  });
}
```

#### DON'T use `async` when it has no useful effect
```dart
// GOOD
Future<void> usesAwait(Future<String> later) async {
  print(await later);
}

Future<void> asyncError() async {
  throw 'Error!';  // async makes this Future.error
}

// BAD - No await, no async behavior
Future<void> asyncNoop() async {
  doSomethingSynchronous();  // Remove async
}
```

#### CONSIDER using higher-order functions on streams
```dart
// GOOD
stream
    .where((event) => event.type == 'click')
    .map((event) => event.target)
    .listen(handleClick);
```

#### AVOID using `Completer` directly
```dart
// GOOD - Use async/await instead
Future<bool> fileExists(String path) async {
  return await File(path).exists();
}

// BAD - Unnecessary complexity
Future<bool> fileExists(String path) {
  var completer = Completer<bool>();
  File(path).exists().then((exists) {
    completer.complete(exists);
  });
  return completer.future;
}
```

#### DO test for `Future<void>` in callbacks with `FutureOr<void>` return type
```dart
Future<void> logRequest(Uri uri) async {
  // If callback is async, await it
  final result = beforeRequest(uri);
  if (result is Future<void>) await result;
  
  // ... rest of logic
}
```

---

## 3. Effective Dart: Design

### 3.1 Names

#### DO use terms consistently
```dart
// GOOD - Pick one term
pageCount
updatePageCount
PageController

// BAD - Inconsistent terminology
pageCount
updatePagination  // "pagination" vs "page"
PageHelper        // "helper" vs "controller"
```

#### AVOID abbreviations unless universally known
```dart
// GOOD
pageCount
buildRenderTree

// BAD
numPages
buildRndTree
```

#### PREFER putting the most descriptive noun last
```dart
// GOOD
pageCount       // count of pages
ConversionSink  // a sink for conversions

// BAD
countPages
SinkConversion
```

#### CONSIDER making code read like a sentence
```dart
// GOOD - Reads naturally
if (errors.isEmpty) { ... }
subscription.cancel();
entries.removeWhere((e) => e.isEmpty);

// BAD
if (errors.empty) { ... }
subscription.dispose();
entries.remove((e) => e.isEmpty);
```

### 3.2 Libraries

#### PREFER making declarations private
```dart
// GOOD
class _HelperClass { ... }

// BAD
class HelperClass { ... }  // Unnecessarily public
```

#### CONSIDER declaring multiple classes in one library for tight coupling
```dart
// In rectangle.dart
class Rectangle {
  // ...
}

class _RectangleIterator implements Iterator<Point> {
  // Private helper, same file
}
```

### 3.3 Classes and Mixins

#### AVOID defining one-member abstract classes for simple functions
```dart
// BAD
abstract class Predicate<T> {
  bool test(T value);
}

// GOOD - Use a typedef
typedef Predicate<T> = bool Function(T value);
```

#### AVOID defining empty classes as markers
```dart
// BAD
abstract class Serializable {}

class Person implements Serializable { ... }

// GOOD - Use annotations or other patterns
```

#### AVOID extending a class that isn't designed for subclassing
The class should document that it's meant to be extended.

#### DO document if a class supports being extended
```dart
/// A base class for all widgets.
///
/// Subclass this to create custom widgets.
abstract class Widget { ... }
```

#### AVOID implementing a class not designed for interface use
Look for documented `@sealed` or similar patterns.

#### DO document if your class can be used as an interface
```dart
/// Implementations must provide [fetch] method.
abstract interface class DataSource {
  Future<Data> fetch(String id);
}
```

#### PREFER `mixin` for reusable behavior
```dart
// GOOD
mixin Scrollable {
  void scrollTo(double offset) { ... }
}

class ListView with Scrollable { ... }
```

### 3.4 Constructors

#### CONSIDER factory constructors for returning existing instances
```dart
class Logger {
  static final Map<String, Logger> _cache = {};
  
  factory Logger(String name) {
    return _cache.putIfAbsent(name, () => Logger._internal(name));
  }
  
  Logger._internal(this.name);
  
  final String name;
}
```

#### DO use `const` constructors when a class supports it
```dart
// GOOD
class Point {
  final double x, y;
  const Point(this.x, this.y);
}

// Can use const
const origin = Point(0, 0);
```

### 3.5 Members

#### PREFER making fields and top-level variables `final`
```dart
// GOOD
class Person {
  final String name;
  final DateTime birthDate;
  
  Person(this.name, this.birthDate);
}
```

#### DO use getters for properties derived from other state
```dart
// GOOD
class Circle {
  final double radius;
  
  Circle(this.radius);
  
  double get area => pi * radius * radius;
  double get circumference => 2 * pi * radius;
}
```

#### DON'T define a setter without a corresponding getter
```dart
// BAD
class Box {
  set contents(Object value) { ... }  // No getter!
}
```

#### AVOID returning `this` from methods just for chaining
```dart
// BAD - Not idiomatic Dart
class StringBuffer {
  StringBuffer write(String s) {
    // ...
    return this;
  }
}

// GOOD - Use cascade operator instead
buffer
  ..write('Hello')
  ..write(' ')
  ..write('World');
```

### 3.6 Types

#### DO annotate return types on public APIs
```dart
// GOOD
String greet(String name) => 'Hello, $name!';

// BAD
greet(String name) => 'Hello, $name!';
```

#### DON'T annotate local variables when type is obvious
```dart
// GOOD
var items = ['Apple', 'Banana'];  // Obviously List<String>
var subscription = stream.listen(handleEvent);

// BAD - Overly verbose
List<String> items = ['Apple', 'Banana'];
StreamSubscription<Event> subscription = stream.listen(handleEvent);
```

#### DON'T annotate inferred parameter types on function expressions
```dart
// GOOD
var names = people.map((person) => person.name);

// BAD
var names = people.map((Person person) => person.name);
```

#### DO annotate when Dart infers the wrong type
```dart
// When you need a specific supertype
num sum = 0;  // Not int
for (var n in numbers) {
  sum += n;
}
```

#### PREFER annotating with `dynamic` over letting inference fail
```dart
// GOOD - Explicit about accepting anything
void log(dynamic message) {
  print(message);
}

// BAD - Implicit dynamic from inference failure
void log(message) {
  print(message);
}
```

#### PREFER signatures in function type annotations
```dart
// GOOD
typedef Comparison<T> = int Function(T a, T b);

// BAD
typedef Comparison<T> = Function;
```

#### DON'T specify return type of setter
```dart
// GOOD
set value(int newValue) { ... }

// BAD
void set value(int newValue) { ... }
```

#### DON'T use legacy typedef syntax
```dart
// GOOD
typedef Comparison<T> = int Function(T a, T b);

// BAD
typedef int Comparison<T>(T a, T b);
```

#### PREFER `Object?` instead of `dynamic` to indicate any object is allowed
```dart
// GOOD - Clearly states "I accept any object"
void log(Object? message) {
  print(message?.toString());
}

// BAD - Loses type safety
void log(dynamic message) {
  print(message.foo);  // No compile-time error!
}
```

#### DO use `Future<void>` as the return type of async functions with no value
```dart
// GOOD
Future<void> save(String data) async {
  await file.writeAsString(data);
}

// BAD
Future save(String data) async { ... }  // Missing void
```

#### AVOID using `FutureOr<T>` as a return type
```dart
// BAD - Forces caller to handle both cases
FutureOr<int> getValue() { ... }

// GOOD - Clear contract
Future<int> getValueAsync() async { ... }
int getValueSync() { ... }
```

### 3.7 Parameters

#### AVOID positional boolean parameters
```dart
// BAD
new Task(true);  // What does true mean?
new Task(false);

// GOOD
Task.oneShot();
Task.repeating();

// Or
new Task(isRepeating: true);
```

#### AVOID optional positional parameters when the meaning isn't clear
```dart
// BAD
String.fromCharCodes(Iterable<int> charCodes, [int start, int end]);

// GOOD
String.fromCharCodes(Iterable<int> charCodes, {int start, int? end});
```

#### DO use `required` for named parameters that must be provided
```dart
// GOOD
class User {
  final String name;
  final int age;
  
  User({required this.name, required this.age});
}
```

#### DO use trailing commas for all multi-line function calls and declarations
```dart
// GOOD
final user = User(
  name: 'John',
  age: 25,
);

// BAD
final user = User(
  name: 'John',
  age: 25);
```

### 3.8 Equality

#### DO override `hashCode` if you override `==`
```dart
class Point {
  final int x, y;
  
  Point(this.x, this.y);
  
  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;
  
  @override
  int get hashCode => Object.hash(x, y);
}
```

#### DO make `==` symmetric and transitive
```dart
// The == operator must satisfy:
// - Symmetric: a == b implies b == a
// - Transitive: a == b and b == c implies a == c
// - Reflexive: a == a is always true
```

---

## 4. Flutter App Architecture

### 4.1 Layers Overview

Flutter applications should be structured into distinct layers:

```
┌─────────────────────────────────────────┐
│              UI Layer                   │
│  (Widgets, Screens, ViewModels)         │
├─────────────────────────────────────────┤
│            Domain Layer                 │
│   (Business Logic, Use Cases)           │
├─────────────────────────────────────────┤
│             Data Layer                  │
│  (Repositories, Data Sources, Models)   │
└─────────────────────────────────────────┘
```

### 4.2 UI Layer

The UI layer displays application data and serves as the primary point of user interaction.

#### Widgets
- Widgets should be **dumb** — they only know how to display data
- No business logic in widgets
- Widgets receive data and callbacks from ViewModels

```dart
class UserProfileScreen extends StatelessWidget {
  final UserProfileViewModel viewModel;
  
  const UserProfileScreen({required this.viewModel, super.key});
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const CircularProgressIndicator();
        }
        
        return Column(
          children: [
            Text(viewModel.user?.name ?? 'Unknown'),
            ElevatedButton(
              onPressed: viewModel.refresh,
              child: const Text('Refresh'),
            ),
          ],
        );
      },
    );
  }
}
```

#### ViewModels
- Hold UI state (loading, error, data)
- Expose methods for user actions
- Call repositories for data operations
- Notify listeners when state changes

```dart
class UserProfileViewModel extends ChangeNotifier {
  final UserRepository _userRepository;
  
  User? _user;
  bool _isLoading = false;
  String? _error;
  
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  UserProfileViewModel({required UserRepository userRepository})
      : _userRepository = userRepository;
  
  Future<void> loadUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _user = await _userRepository.getUser(userId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> refresh() async {
    if (_user != null) {
      await loadUser(_user!.id);
    }
  }
}
```

### 4.3 Data Layer

The data layer handles all data operations and exposes data to the rest of the application.

#### Repositories
- **Single source of truth** for a domain entity
- Abstract data sources (local, remote, cache)
- Handle data synchronization logic
- Map external data to domain models

```dart
abstract class UserRepository {
  Future<User> getUser(String id);
  Future<void> saveUser(User user);
  Stream<User> watchUser(String id);
}

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource _remote;
  final UserLocalDataSource _local;
  
  UserRepositoryImpl({
    required UserRemoteDataSource remote,
    required UserLocalDataSource local,
  })  : _remote = remote,
        _local = local;
  
  @override
  Future<User> getUser(String id) async {
    try {
      // Try remote first
      final user = await _remote.fetchUser(id);
      await _local.cacheUser(user);
      return user;
    } catch (e) {
      // Fall back to cache
      final cached = await _local.getUser(id);
      if (cached != null) return cached;
      rethrow;
    }
  }
  
  @override
  Future<void> saveUser(User user) async {
    await _remote.updateUser(user);
    await _local.cacheUser(user);
  }
  
  @override
  Stream<User> watchUser(String id) {
    return _local.watchUser(id);
  }
}
```

#### Data Sources
- Handle raw data operations
- Remote: API calls, GraphQL, Firebase
- Local: SharedPreferences, SQLite, Hive

```dart
class UserRemoteDataSource {
  final http.Client _client;
  final String _baseUrl;
  
  UserRemoteDataSource({
    required http.Client client,
    required String baseUrl,
  })  : _client = client,
        _baseUrl = baseUrl;
  
  Future<User> fetchUser(String id) async {
    final response = await _client.get(Uri.parse('$_baseUrl/users/$id'));
    
    if (response.statusCode != 200) {
      throw HttpException('Failed to fetch user: ${response.statusCode}');
    }
    
    return User.fromJson(jsonDecode(response.body));
  }
}
```

#### Models
- **Immutable** data classes
- Use `copyWith` for modifications
- Include serialization methods

```dart
@immutable
class User {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;
  
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });
  
  User copyWith({
    String? name,
    String? email,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt,
    );
  }
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          createdAt == other.createdAt;
  
  @override
  int get hashCode => Object.hash(id, name, email, createdAt);
}
```

### 4.4 Dependency Injection

Use constructor injection for testability:

```dart
// In main.dart or a DI configuration
final httpClient = http.Client();
final userRemoteDataSource = UserRemoteDataSource(
  client: httpClient,
  baseUrl: 'https://api.example.com',
);
final userLocalDataSource = UserLocalDataSource(
  preferences: await SharedPreferences.getInstance(),
);
final userRepository = UserRepositoryImpl(
  remote: userRemoteDataSource,
  local: userLocalDataSource,
);

// ViewModels receive repositories
final viewModel = UserProfileViewModel(userRepository: userRepository);
```

---

## 5. BLoC Pattern

### 5.1 Cubit (Simpler State Management)

Cubit is a lightweight version of Bloc that uses functions instead of events.

```dart
// State
@immutable
sealed class CounterState {
  final int count;
  const CounterState(this.count);
}

final class CounterInitial extends CounterState {
  const CounterInitial() : super(0);
}

final class CounterUpdated extends CounterState {
  const CounterUpdated(super.count);
}

// Cubit
class CounterCubit extends Cubit<CounterState> {
  CounterCubit() : super(const CounterInitial());
  
  void increment() => emit(CounterUpdated(state.count + 1));
  void decrement() => emit(CounterUpdated(state.count - 1));
}

// Usage
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterCubit(),
      child: BlocBuilder<CounterCubit, CounterState>(
        builder: (context, state) {
          return Column(
            children: [
              Text('Count: ${state.count}'),
              ElevatedButton(
                onPressed: () => context.read<CounterCubit>().increment(),
                child: const Text('Increment'),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

### 5.2 Bloc (Full Event-Driven Pattern)

Use Bloc when you need:
- Event transformations (debounce, throttle)
- Complex event handling
- Event traceability

```dart
// Events
@immutable
sealed class AuthEvent {}

final class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  
  AuthLoginRequested({required this.email, required this.password});
}

final class AuthLogoutRequested extends AuthEvent {}

// States
@immutable
sealed class AuthState {}

final class AuthInitial extends AuthState {}

final class AuthLoading extends AuthState {}

final class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}

final class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  
  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }
  
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final user = await _authRepository.login(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
  
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(AuthInitial());
  }
}
```

### 5.3 BlocObserver

Monitor all Bloc/Cubit state changes globally:

```dart
class AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    debugPrint('onCreate -- ${bloc.runtimeType}');
  }
  
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    debugPrint('onChange -- ${bloc.runtimeType}: $change');
  }
  
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    debugPrint('onError -- ${bloc.runtimeType}: $error');
    super.onError(bloc, error, stackTrace);
  }
  
  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    debugPrint('onClose -- ${bloc.runtimeType}');
  }
}

// In main.dart
void main() {
  Bloc.observer = AppBlocObserver();
  runApp(const MyApp());
}
```

### 5.4 Cubit vs Bloc Decision Guide

| Use Case | Recommended |
|----------|-------------|
| Simple state changes | **Cubit** |
| Form handling | **Cubit** |
| Toggle states | **Cubit** |
| Complex async flows | **Bloc** |
| Need event debouncing/throttling | **Bloc** |
| Need event traceability | **Bloc** |
| Real-time features (WebSocket) | **Bloc** |

---

## 6. Riverpod State Management

### 6.1 Provider Types

```dart
// Simple value provider
final counterProvider = Provider<int>((ref) => 0);

// Mutable state provider
final counterStateProvider = StateProvider<int>((ref) => 0);

// Notifier provider (recommended for complex state)
final counterNotifierProvider = NotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
);

class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;
  
  void increment() => state++;
  void decrement() => state--;
}

// Async provider
final userProvider = FutureProvider<User>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUser();
});

// Async notifier provider
final asyncCounterProvider = AsyncNotifierProvider<AsyncCounterNotifier, int>(
  AsyncCounterNotifier.new,
);

class AsyncCounterNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    // Fetch initial value
    return 0;
  }
  
  Future<void> increment() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await Future.delayed(const Duration(seconds: 1));
      return (state.value ?? 0) + 1;
    });
  }
}

// Stream provider
final messagesProvider = StreamProvider<List<Message>>((ref) {
  final repository = ref.watch(messageRepositoryProvider);
  return repository.watchMessages();
});
```

### 6.2 Provider Modifiers

```dart
// Family - parameterized providers
final userProvider = FutureProvider.family<User, String>((ref, userId) {
  return ref.watch(userRepositoryProvider).getUser(userId);
});

// Usage
final user = ref.watch(userProvider('user-123'));

// Auto-dispose - automatically dispose when no longer used
final searchProvider = StateProvider.autoDispose<String>((ref) => '');

// Keep alive for specific duration
final cacheProvider = FutureProvider.autoDispose<Data>((ref) {
  ref.keepAlive();  // Prevent auto-dispose
  
  final timer = Timer(const Duration(minutes: 5), () {
    ref.invalidateSelf();  // Invalidate after 5 minutes
  });
  
  ref.onDispose(timer.cancel);
  
  return fetchData();
});
```

### 6.3 Widget Integration

```dart
// With ConsumerWidget
class CounterScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    
    return Scaffold(
      body: Center(child: Text('Count: $count')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(counterNotifierProvider.notifier).increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// With Consumer widget for partial rebuilds
class OptimizedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ExpensiveWidget(),  // Won't rebuild
        Consumer(
          builder: (context, ref, child) {
            final count = ref.watch(counterProvider);
            return Text('Count: $count');
          },
        ),
      ],
    );
  }
}

// Handle async states
class UserScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    
    return userAsync.when(
      data: (user) => Text(user.name),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

---

## 7. Linting & Analysis

### 7.1 Recommended Analysis Options

Based on [very_good_analysis](https://github.com/VeryGoodOpenSource/very_good_analysis):

```yaml
# analysis_options.yaml
include: package:very_good_analysis/analysis_options.yaml

# Or manually configure strict analysis:
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  
  errors:
    missing_required_param: error
    missing_return: error
    parameter_assignments: error
    dead_code: warning
    todo: ignore
  
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/generated/**"

linter:
  rules:
    # Error prevention
    - always_use_package_imports
    - avoid_dynamic_calls
    - avoid_empty_else
    - avoid_print
    - avoid_relative_lib_imports
    - avoid_returning_null_for_future
    - avoid_slow_async_io
    - avoid_type_to_string
    - avoid_types_as_parameter_names
    - avoid_web_libraries_in_flutter
    - cancel_subscriptions
    - close_sinks
    - literal_only_boolean_expressions
    - no_adjacent_strings_in_list
    - no_duplicate_case_values
    - prefer_void_to_null
    - throw_in_finally
    - unnecessary_statements
    - use_key_in_widget_constructors
    
    # Style
    - always_declare_return_types
    - always_put_required_named_parameters_first
    - always_require_non_null_named_parameters
    - annotate_overrides
    - avoid_annotating_with_dynamic
    - avoid_bool_literals_in_conditional_expressions
    - avoid_catches_without_on_clauses
    - avoid_catching_errors
    - avoid_equals_and_hash_code_on_mutable_classes
    - avoid_escaping_inner_quotes
    - avoid_field_initializers_in_const_classes
    - avoid_final_parameters
    - avoid_function_literals_in_foreach_calls
    - avoid_implementing_value_types
    - avoid_init_to_null
    - avoid_js_rounded_ints
    - avoid_multiple_declarations_per_line
    - avoid_null_checks_in_equality_operators
    - avoid_positional_boolean_parameters
    - avoid_private_typedef_functions
    - avoid_redundant_argument_values
    - avoid_renaming_method_parameters
    - avoid_return_types_on_setters
    - avoid_returning_null
    - avoid_returning_this
    - avoid_setters_without_getters
    - avoid_shadowing_type_parameters
    - avoid_single_cascade_in_expression_statements
    - avoid_types_on_closure_parameters
    - avoid_unnecessary_containers
    - avoid_unused_constructor_parameters
    - avoid_void_async
    - await_only_futures
    - camel_case_extensions
    - camel_case_types
    - cascade_invocations
    - cast_nullable_to_non_nullable
    - combinators_ordering
    - conditional_uri_does_not_exist
    - constant_identifier_names
    - curly_braces_in_flow_control_structures
    - deprecated_consistency
    - directives_ordering
    - do_not_use_environment
    - empty_catches
    - empty_constructor_bodies
    - eol_at_end_of_file
    - exhaustive_cases
    - file_names
    - flutter_style_todos
    - hash_and_equals
    - implementation_imports
    - implicit_call_tearoffs
    - join_return_with_assignment
    - leading_newlines_in_multiline_strings
    - library_annotations
    - library_names
    - library_prefixes
    - library_private_types_in_public_api
    - lines_longer_than_80_chars
    - missing_whitespace_between_adjacent_strings
    - no_leading_underscores_for_library_prefixes
    - no_leading_underscores_for_local_identifiers
    - no_literal_bool_comparisons
    - no_runtimeType_toString
    - non_constant_identifier_names
    - noop_primitive_operations
    - null_check_on_nullable_type_parameter
    - null_closures
    - omit_local_variable_types
    - one_member_abstracts
    - only_throw_errors
    - overridden_fields
    - package_api_docs
    - package_prefixed_library_names
    - parameter_assignments
    - prefer_adjacent_string_concatenation
    - prefer_asserts_in_initializer_lists
    - prefer_collection_literals
    - prefer_conditional_assignment
    - prefer_const_constructors
    - prefer_const_constructors_in_immutables
    - prefer_const_declarations
    - prefer_const_literals_to_create_immutables
    - prefer_constructors_over_static_methods
    - prefer_contains
    - prefer_expression_function_bodies
    - prefer_final_fields
    - prefer_final_in_for_each
    - prefer_final_locals
    - prefer_for_elements_to_map_fromIterable
    - prefer_function_declarations_over_variables
    - prefer_generic_function_type_aliases
    - prefer_if_elements_to_conditional_expressions
    - prefer_if_null_operators
    - prefer_initializing_formals
    - prefer_inlined_adds
    - prefer_int_literals
    - prefer_interpolation_to_compose_strings
    - prefer_is_empty
    - prefer_is_not_empty
    - prefer_is_not_operator
    - prefer_iterable_whereType
    - prefer_mixin
    - prefer_null_aware_method_calls
    - prefer_null_aware_operators
    - prefer_single_quotes
    - prefer_spread_collections
    - prefer_typing_uninitialized_variables
    - provide_deprecation_message
    - public_member_api_docs
    - recursive_getters
    - require_trailing_commas
    - sized_box_for_whitespace
    - sized_box_shrink_expand
    - slash_for_doc_comments
    - sort_child_properties_last
    - sort_constructors_first
    - sort_pub_dependencies
    - sort_unnamed_constructors_first
    - tighten_type_of_initializing_formals
    - type_annotate_public_apis
    - type_init_formals
    - unawaited_futures
    - unnecessary_await_in_return
    - unnecessary_brace_in_string_interps
    - unnecessary_breaks
    - unnecessary_const
    - unnecessary_constructor_name
    - unnecessary_getters_setters
    - unnecessary_lambdas
    - unnecessary_late
    - unnecessary_library_directive
    - unnecessary_new
    - unnecessary_null_aware_assignments
    - unnecessary_null_aware_operator_on_extension_on_nullable
    - unnecessary_null_checks
    - unnecessary_null_in_if_null_operators
    - unnecessary_nullable_for_final_variable_declarations
    - unnecessary_overrides
    - unnecessary_parenthesis
    - unnecessary_raw_strings
    - unnecessary_string_escapes
    - unnecessary_string_interpolations
    - unnecessary_this
    - unnecessary_to_list_in_spreads
    - unreachable_from_main
    - unrelated_type_equality_checks
    - use_colored_box
    - use_decorated_box
    - use_enums
    - use_full_hex_values_for_flutter_colors
    - use_function_type_syntax_for_parameters
    - use_if_null_to_convert_nulls_to_bools
    - use_is_even_rather_than_modulo
    - use_late_for_private_fields_when_needed
    - use_named_constants
    - use_raw_strings
    - use_rethrow_when_possible
    - use_setters_to_change_properties
    - use_string_buffers
    - use_string_in_part_of_directives
    - use_super_parameters
    - use_test_throws_matchers
    - use_to_and_as_if_applicable
    - void_checks
```

### 7.2 Quick Setup

```yaml
# pubspec.yaml
dev_dependencies:
  very_good_analysis: ^6.0.0  # Check for latest version
```

```yaml
# analysis_options.yaml
include: package:very_good_analysis/analysis_options.yaml
```

---

## 8. Testing

### 8.1 Unit Testing

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Mock generation (with build_runner)
@GenerateMocks([UserRepository])
void main() {
  group('UserProfileViewModel', () {
    late MockUserRepository mockRepository;
    late UserProfileViewModel viewModel;
    
    setUp(() {
      mockRepository = MockUserRepository();
      viewModel = UserProfileViewModel(userRepository: mockRepository);
    });
    
    test('loadUser sets user on success', () async {
      // Arrange
      final user = User(id: '1', name: 'John', email: 'john@example.com');
      when(mockRepository.getUser('1')).thenAnswer((_) async => user);
      
      // Act
      await viewModel.loadUser('1');
      
      // Assert
      expect(viewModel.user, equals(user));
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
    });
    
    test('loadUser sets error on failure', () async {
      // Arrange
      when(mockRepository.getUser('1')).thenThrow(Exception('Network error'));
      
      // Act
      await viewModel.loadUser('1');
      
      // Assert
      expect(viewModel.user, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, contains('Network error'));
    });
  });
}
```

### 8.2 Widget Testing

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CounterPage displays count and increments', (tester) async {
    // Build the widget
    await tester.pumpWidget(
      const MaterialApp(home: CounterPage()),
    );
    
    // Verify initial state
    expect(find.text('Count: 0'), findsOneWidget);
    
    // Tap the increment button
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    
    // Verify updated state
    expect(find.text('Count: 1'), findsOneWidget);
  });
  
  testWidgets('shows loading indicator when loading', (tester) async {
    // Create a mock view model in loading state
    final viewModel = UserProfileViewModel(/* mock */);
    viewModel.setLoading(true);
    
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen(viewModel: viewModel),
      ),
    );
    
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

### 8.3 BLoC Testing

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CounterCubit', () {
    blocTest<CounterCubit, CounterState>(
      'emits [CounterUpdated(1)] when increment is called',
      build: () => CounterCubit(),
      act: (cubit) => cubit.increment(),
      expect: () => [const CounterUpdated(1)],
    );
    
    blocTest<CounterCubit, CounterState>(
      'emits [CounterUpdated(-1)] when decrement is called',
      build: () => CounterCubit(),
      act: (cubit) => cubit.decrement(),
      expect: () => [const CounterUpdated(-1)],
    );
  });
  
  group('AuthBloc', () {
    late MockAuthRepository mockRepository;
    
    setUp(() {
      mockRepository = MockAuthRepository();
    });
    
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on successful login',
      build: () => AuthBloc(authRepository: mockRepository),
      setUp: () {
        when(mockRepository.login(email: any, password: any))
            .thenAnswer((_) async => User(id: '1', name: 'Test'));
      },
      act: (bloc) => bloc.add(AuthLoginRequested(
        email: 'test@example.com',
        password: 'password',
      )),
      expect: () => [
        AuthLoading(),
        isA<AuthAuthenticated>(),
      ],
    );
  });
}
```

### 8.4 Integration Testing

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('complete user flow', (tester) async {
    // Launch the app
    app.main();
    await tester.pumpAndSettle();
    
    // Login
    await tester.enterText(find.byKey(Key('email_field')), 'test@example.com');
    await tester.enterText(find.byKey(Key('password_field')), 'password');
    await tester.tap(find.byKey(Key('login_button')));
    await tester.pumpAndSettle();
    
    // Verify we're on the home page
    expect(find.text('Welcome'), findsOneWidget);
    
    // Navigate to profile
    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();
    
    // Verify profile page
    expect(find.text('test@example.com'), findsOneWidget);
  });
}
```

### 8.5 Test File Organization

```
lib/
├── features/
│   └── auth/
│       ├── data/
│       │   └── auth_repository.dart
│       ├── presentation/
│       │   ├── bloc/
│       │   │   └── auth_bloc.dart
│       │   └── pages/
│       │       └── login_page.dart
│       └── domain/
│           └── entities/
│               └── user.dart

test/
├── features/
│   └── auth/
│       ├── data/
│       │   └── auth_repository_test.dart
│       ├── presentation/
│       │   ├── bloc/
│       │   │   └── auth_bloc_test.dart
│       │   └── pages/
│       │       └── login_page_test.dart
│       └── domain/
│           └── entities/
│               └── user_test.dart
├── helpers/
│   ├── mocks.dart
│   └── pump_app.dart

integration_test/
└── app_test.dart
```

---

## Quick Reference Card

### Naming Conventions
| Type | Convention | Example |
|------|------------|---------|
| Classes, enums, typedefs, extensions | `UpperCamelCase` | `HttpRequest`, `UserRepository` |
| Variables, parameters, functions | `lowerCamelCase` | `httpRequest`, `loadUser()` |
| Constants | `lowerCamelCase` | `defaultTimeout` (NOT `kDefaultTimeout`) |
| Files, packages, directories | `lowercase_with_underscores` | `user_repository.dart` |
| Private members | `_prefixed` | `_cache`, `_internal()` |

### Async Checklist
- [ ] Use `async`/`await` over raw Futures
- [ ] Return type is `Future<void>` (not just `Future`)
- [ ] Errors are caught and handled appropriately
- [ ] Subscriptions are canceled in `dispose()`
- [ ] Streams are closed when done

### Architecture Checklist
- [ ] Widgets are dumb (no business logic)
- [ ] ViewModels/Blocs handle state
- [ ] Repositories abstract data sources
- [ ] Models are immutable with `copyWith`
- [ ] Dependencies are injected via constructor

### Before Commit Checklist
- [ ] `dart format .` passes
- [ ] `dart analyze` shows no issues
- [ ] All tests pass
- [ ] No `print()` statements in production code
- [ ] No `// TODO` without ticket reference
