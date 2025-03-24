const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

router.get('/login', authController.login);
router.get('/callback', authController.callback);
router.post('/token', authController.token); // Add this line
router.post('/refresh', authController.refresh);
router.get('/auth_callback', authController.auth_callback);

module.exports = router;
