const express = require('express');
const router = express.Router();
const blogController = require('../controllers/blog');

router.get('/:id/view', blogController.getPost);
router.get('', blogController.getPosts);
router.post('/', blogController.createPost);
router.get('/:id/edit', blogController.getEditPost);
router.post('/:id', blogController.updatePost);
router.post('/:id/delete', blogController.deletePost);

module.exports = router;
