/// The custom HTML page shown in the browser after a successful Google Sign-In.
const String customAuthSuccessHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OmniBridge Authentication</title>
    <style>
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e1e2f, #2a2a40);
            color: #ffffff;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.05);
            padding: 40px 60px;
            border-radius: 16px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            backdrop-filter: blur(10px);
            animation: slideUp 0.6s cubic-bezier(0.2, 0.8, 0.2, 1);
        }
        .logo {
            font-size: 3rem;
            margin-bottom: 20px;
        }
        h1 {
            font-size: 2rem;
            margin: 0 0 10px;
            background: linear-gradient(90deg, #4facfe, #00f2fe);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        p {
            font-size: 1.1rem;
            color: #b0b0c0;
            margin: 0;
        }
        .pulse {
            display: inline-block;
            width: 12px;
            height: 12px;
            background-color: #00f2fe;
            border-radius: 50%;
            margin-top: 30px;
            box-shadow: 0 0 0 0 rgba(0, 242, 254, 0.7);
            animation: pulse 1.5s infinite;
        }
        @keyframes slideUp {
            from { opacity: 0; transform: translateY(30px); }
            to { opacity: 1; transform: translateY(0); }
        }
        @keyframes pulse {
            0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(0, 242, 254, 0.7); }
            70% { transform: scale(1); box-shadow: 0 0 0 10px rgba(0, 242, 254, 0); }
            100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(0, 242, 254, 0); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🌉</div>
        <h1>Authentication Successful</h1>
        <p>You can securely close this tab and return to OmniBridge.</p>
        <div class="pulse"></div>
    </div>
</body>
</html>
''';
