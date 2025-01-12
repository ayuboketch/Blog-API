const express = require('express');
const { PrismaClient } = require('@prisma/client');

const router = express.Router();
const prisma = new PrismaClient();

// Get comments for a post
router.get('/post/:postId', async (req, res) => {
  try {
    const comments = await prisma.comment.findMany({
      where: { postId: req.params.postId },
      include: {
        author: {
          select: {
            name: true
          }
        }
      }
    });
    res.json(comments);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Create a comment
router.post('/', async (req, res) => {
  try {
    const { content, postId } = req.body;
    const comment = await prisma.comment.create({
      data: {
        content,
        postId,
        authorId: req.user.id
      }
    });
    res.json(comment);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Delete a comment (protected)
router.delete('/:id', async (req, res) => {
  try {
    await prisma.comment.delete({
      where: { id: req.params.id }
    });
    res.json({ message: 'Comment deleted' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

module.exports = router;