const axios = require('axios');
const { sessions } = require('./authController');

// Helper function to refresh tokens
async function refreshToken(appToken) {
  const session = sessions[appToken];
  
  const response = await axios.post('https://www.reddit.com/api/v1/access_token',
    new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: session.redditRefreshToken
    }).toString(),
    {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': `Basic ${Buffer.from(`${process.env.REDDIT_CLIENT_ID}:${process.env.REDDIT_CLIENT_SECRET}`).toString('base64')}`
      }
    }
  );
  
  session.redditAccessToken = response.data.access_token;
  session.expiresAt = Date.now() + (response.data.expires_in * 1000);
}

exports.proxy = async (req, res) => {
  const appToken = req.headers.authorization?.split(' ')[1];
  
  if (!appToken || !sessions[appToken]) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  const session = sessions[appToken];
  
  // Check if token needs refresh
  if (session.expiresAt - 300000 < Date.now()) {
    // Token is expired or about to expire, refresh it
    try {
      await refreshToken(appToken);
    } catch (error) {
      return res.status(401).json({ error: 'Authentication expired' });
    }
  }
  
  try {
    // Forward request to Reddit with your stored access token
    const redditPath = req.path;
    const redditUrl = `https://oauth.reddit.com${redditPath}${req.url.includes('?') ? req.url.substring(req.url.indexOf('?')) : ''}`;
    
    const response = await axios.get(redditUrl, {
      headers: {
        'Authorization': `Bearer ${session.redditAccessToken}`,
        'User-Agent': 'ReddKit/1.0.0'
      }
    });
    
    res.json(response.data);
  } catch (error) {
    console.error('API proxy error:', error);
    res.status(error.response?.status || 500).json(error.response?.data || { error: 'API request failed' });
  }
};