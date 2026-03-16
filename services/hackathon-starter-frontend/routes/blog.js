const express = require('express');
const router = express.Router();
const blogController = require('../controllers/blog');
const passportConfig = require('../config/passport');

router.get('/:id/view', blogController.getPost);
router.get('', blogController.getPosts);
router.get('/new', passportConfig.isAuthenticated, blogController.getNewPost);
router.post('/', passportConfig.isAuthenticated, blogController.createPost);
router.get('/:id/edit', passportConfig.isAuthenticated, blogController.getEditPost);
router.post('/:id', passportConfig.isAuthenticated, blogController.updatePost);
router.post('/:id/delete', passportConfig.isAuthenticated, blogController.deletePost);

module.exports = router; //export default
