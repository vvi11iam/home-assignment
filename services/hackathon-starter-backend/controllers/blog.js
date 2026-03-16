const BlogPost = require('../models/BlogPost');
const { marked } = require('marked');

// Function to truncate a string to a certain number of lines
// and add ellipsis if it exceeds that number
const truncate = (str, maxLines = 5) => {
  const lines = str.split('\n').filter(Boolean); // remove empty lines
  return lines.slice(0, maxLines).join('\n') + (lines.length > maxLines ? '\n...' : '');
};

/**
 * GET /blog
 * List all blog posts.
 */
exports.getPosts = async (req, res) => {
  const posts = await BlogPost.find().populate('author', 'email');

  // Sort posts by createdAt in descending order
  posts.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

  // Create previews for each post
  // Use marked to convert markdown to HTML
  // Use truncate to limit the preview to a certain number of lines
  // Use map to create an array of previews
  // Use destructuring to extract the properties we need
  const previews = posts.map((post) => ({
    title: post.title,
    _id: post._id,
    preview: truncate(marked(post.content)),
    author: post.author,
    createdAt: post.createdAt.toDateString(),
  }));

  res.send(previews);
};

/**
 * GET /blog/:id/view
 * Return a single blog post.
 */
exports.getPost = async (req, res) => {
  try {
    const post = await BlogPost.findById(req.params.id);

    if (!post) {
      return res.status(404).send('Post not found');
    }

    const content = marked(post.content); // Convert markdown to HTML

    res.send({ ...post._doc, content });
  } catch (err) {
    console.error(err);
    res.status(500).send('Something went wrong');
  }
};

/**
 * POST /blog
 * Create a new blog post.
 */
exports.createPost = async (req, res) => {
  await BlogPost.create({
    title: req.body.title,
    content: req.body.content,
    author: req.body.author,
  });
  console.log('Post created');
  res.send('Post created');
};

/**
 * GET /blog/:id/edit
 * Return form to edit a post.
 */
exports.getEditPost = async (req, res) => {
  try {
    const post = await BlogPost.findById(req.params.id);

    if (!post) {
      return res.status(404).send('Post not found');
    }

    res.send(post);
  } catch (err) {
    console.error(err);
    res.status(500).send('Something went wrong');
  }
};

/**
 * POST /blog/:id
 * Update a blog post.
 */
exports.updatePost = async (req, res) => {
  // Check if the user is the author of the post
  // If not, return a 403 Forbidden status
  // If yes, allowed to update the post
  const post = await BlogPost.findById(req.params.id).populate('author', 'email');
  if (post.author._id.toString() !== req.body.author) {
    return res.status(403).send('You are not the author of this post');
  }

  await BlogPost.findByIdAndUpdate(req.params.id, {
    title: req.body.title,
    content: req.body.content,
  });
  console.log('Post updated');
  res.send('Post updated');
};

/**
 * POST /blog/:id/delete
 * Delete a blog post.
 */
exports.deletePost = async (req, res) => {
  // Check if the user is the author of the post
  // If not, return a 403 Forbidden status
  // If yes, delete the post
  const post = await BlogPost.findById(req.params.id).populate('author', 'email');
  if (post.author._id.toString() !== req.body.author) {
    return res.status(403).send('You are not the author of this post');
  }

  await BlogPost.findByIdAndDelete(req.params.id);
  console.log('Post deleted');
  res.send('Post deleted');
};
