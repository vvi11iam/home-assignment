const axios = require('axios'); // to talk to backend

/**
 * GET /blog
 * List all blog posts.
 */
exports.getPosts = async (req, res) => {
  await axios
    .get(`${process.env.BACKEND_URL}/blog`)
    .then((response) => {
      res.render('blog/list', { title: 'Blog', posts: response.data });
    })
    .catch((err) => {
      // console.error(err.code);
      console.error('Error:', err.response?.data || err.message || err.code);
      req.flash('errors', { msg: err.response?.data || err.message || err.code });
      res.redirect('/');
    });
};

/**
 * GET /blog/:id/view
 * Render a single blog post.
 */
exports.getPost = async (req, res) => {
  const { data } = await axios.get(`${process.env.BACKEND_URL}/blog/${req.params.id}/view`);

  res.render('blog/view', {
    title: data.title,
    _id: data._id,
    content: data.content,
  });
};

/**
 * GET /blog/new
 * Render form to create a new post.
 */
exports.getNewPost = (req, res) => {
  res.render('blog/new', { title: 'New Post' });
};

/**
 * POST /blog
 * Create a new blog post.
 */
exports.createPost = async (req, res) => {
  await axios
    .post(`${process.env.BACKEND_URL}/blog`, {
      title: req.body.title,
      content: req.body.content,
      author: req.user._id,
    })
    .then((response) => {
      console.log('Success!', response.data);
      req.flash('success', { msg: response.data });
    })
    .catch((err) => {
      console.error('Error:', err.response?.data || err.message);
    });
  res.redirect('/blog');
};

/**
 * GET /blog/:id/edit
 * Render form to edit a post.
 */
exports.getEditPost = async (req, res) => {
  const { data } = await axios.get(`${process.env.BACKEND_URL}/blog/${req.params.id}/edit`);
  res.render('blog/edit', { title: 'Edit Post', post: data });
};

/**
 * POST /blog/:id
 * Update a blog post.
 */
exports.updatePost = async (req, res) => {
  await axios
    .post(`${process.env.BACKEND_URL}/blog/${req.params.id}`, {
      title: req.body.title,
      content: req.body.content,
      author: req.user._id,
    })
    .then((response) => {
      console.log('Success!', response.data);
      req.flash('success', { msg: response.data });
    })
    .catch((err) => {
      console.error('Error:', err.response?.data || err.message);
      req.flash('errors', { msg: err.response.data || err.message });
    });
  res.redirect('/blog');
};

/**
 * POST /blog/:id/delete
 * Delete a blog post.
 */
exports.deletePost = async (req, res) => {
  await axios
    .post(`${process.env.BACKEND_URL}/blog/${req.params.id}/delete`, {
      author: req.user._id,
    })
    .then((response) => {
      console.log('Success!', response.data);
      req.flash('success', { msg: response.data });
    })
    .catch((err) => {
      console.error('Error:', err.response?.data || err.message);
      req.flash('errors', { msg: err.response.data || err.message });
    });
  res.redirect('/blog');
};
