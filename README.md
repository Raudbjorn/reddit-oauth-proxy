# Reddit OAuth Proxy

A Node.js Express application that serves as an OAuth proxy for Reddit API authentication.

## Project Structure

```
reddit-oauth-proxy/
├── src/
│   ├── app.js              # Entry point of the application
│   ├── controllers/        # Contains controller files
│   │   ├── authController.js # Authentication controller
│   │   └── apiController.js  # API proxy controller
│   └── routes/             # Contains route files
│       ├── auth.js         # Auth routes
│       └── api.js          # API proxy routes
├── nginx/
│   └── reddit-oauth-proxy.conf # Nginx configuration
├── systemd/
│   └── reddit-oauth-proxy.service # Systemd service file
├── .env                    # Environment variables (not in git)
├── package.json            # NPM configuration file
├── README.md               # Project documentation
└── install-service.sh      # Service installation script
```

## Getting Started

1. Clone the repository:
   ```
   git clone <repository-url>
   cd reddit-oauth-proxy
   ```

2. Install dependencies:
   ```
   npm install
   ```

3. Create a `.env` file with your Reddit OAuth credentials:
   ```
   REDDIT_CLIENT_ID=your_client_id
   REDDIT_CLIENT_SECRET=your_client_secret
   REDDIT_REDIRECT_URI=https://auth.sveinbjorn.dev/callback
   PORT=3000
   ```

4. Start the application:
   ```
   npm start
   ```

## API Endpoints

- `GET /login` - Initiates the Reddit OAuth flow
- `GET /callback` - Handles the OAuth callback from Reddit
- `POST /refresh` - Refreshes an expired token
- `GET /api/*` - Proxies authenticated requests to Reddit's API

## Installing as a System Service

1. Make the installation script executable:
   ```
   chmod +x install-service.sh
   ```

2. Run the installation script with sudo:
   ```
   sudo ./install-service.sh
   ```

3. The script will prompt you for your Reddit OAuth credentials and other configuration options.

4. Once installed, you can manage the service with standard systemd commands:
   ```
   sudo systemctl status reddit-oauth-proxy
   sudo systemctl restart reddit-oauth-proxy
   sudo systemctl stop reddit-oauth-proxy
   ```

5. View logs with:
   ```
   sudo journalctl -u reddit-oauth-proxy
   ```

## License

This project is licensed under the MIT License.