import 'package:flutter/material.dart';
import 'package:dixa_messenger_flutter/dixa_messenger_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DixaMessengerInstance? supportMessenger;
  DixaMessengerInstance? salesMessenger;
  int supportUnreadCount = 0;
  int salesUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    initializeMessengers();
  }

  Future<void> initializeMessengers() async {
    // Initialize support messenger
    final supportConfig = DixaMessengerConfig(
      apiKey: 'a1b86efc99424217b563e007f9cc9a9e',
      logLevel: DixaLogLevel.all,
      supportedLanguages: ['de'],
      authentication: DixaAuthenticationConfig.claimed(
        username: 'John Doe',
        email: 'john@example.com',
      ),
    );
    
    supportMessenger = await DixaMessengerFlutter.createInstance(
      'support',
      supportConfig,
    );
    
    // Initialize sales messenger  
    final salesConfig = DixaMessengerConfig(
      apiKey: '4fc12408465047c1a358a694e15efd1a',
      logLevel: DixaLogLevel.warning,
      authentication: DixaAuthenticationConfig.anonymous(),
    );
    
    salesMessenger = await DixaMessengerFlutter.createInstance(
      'sales', 
      salesConfig,
    );
    
    // Set up unread message listeners
    supportMessenger?.setUnreadMessagesCountListener((count) {
      setState(() {
        supportUnreadCount = count;
      });
    });
    
    salesMessenger?.setUnreadMessagesCountListener((count) {
      setState(() {
        salesUnreadCount = count;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Dixa Messenger Example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  supportMessenger?.openMessenger();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Open Support Chat'),
                    if (supportUnreadCount > 0) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$supportUnreadCount',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  salesMessenger?.openMessenger();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Open Sales Chat'),
                    if (salesUnreadCount > 0) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$salesUnreadCount',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}