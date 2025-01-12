/*
  # Blog Schema Setup the commands are as follows -

  1. New Tables
    - `users` - Stores user profiles linked to auth.users
      - `id` (uuid, primary key, linked to auth.users)
      - `name` (text)
      - `role` (text, either 'USER' or 'ADMIN')
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `posts` - Stores blog posts
      - `id` (uuid, primary key)
      - `title` (text)
      - `content` (text)
      - `published` (boolean)
      - `author_id` (uuid, references users)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `comments` - Stores post comments
      - `id` (uuid, primary key)
      - `content` (text)
      - `post_id` (uuid, references posts)
      - `author_id` (uuid, references users)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Policies for users:
      - Anyone can read user profiles
      - Users can only update their own profile
    - Policies for posts:
      - Anyone can read published posts
      - Authors can CRUD their own posts
      - Admins can CRUD all posts
    - Policies for comments:
      - Anyone can read comments on published posts
      - Authenticated users can create comments
      - Users can update/delete their own comments
      - Admins can moderate all comments
*/

-- Create users table
CREATE TABLE users (
  id uuid PRIMARY KEY REFERENCES auth.users,
  name text NOT NULL,
  role text NOT NULL DEFAULT 'USER' CHECK (role IN ('USER', 'ADMIN')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create posts table
CREATE TABLE posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  content text NOT NULL,
  published boolean DEFAULT false,
  author_id uuid REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create comments table
CREATE TABLE comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content text NOT NULL,
  post_id uuid REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  author_id uuid REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users are viewable by everyone" 
  ON users FOR SELECT 
  USING (true);

CREATE POLICY "Users can update own profile" 
  ON users FOR UPDATE 
  USING (auth.uid() = id);

-- Posts policies
CREATE POLICY "Published posts are viewable by everyone" 
  ON posts FOR SELECT 
  USING (published = true);

CREATE POLICY "Authors can view all own posts" 
  ON posts FOR SELECT 
  USING (author_id = auth.uid());

CREATE POLICY "Authors can create posts" 
  ON posts FOR INSERT 
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "Authors can update own posts" 
  ON posts FOR UPDATE 
  USING (author_id = auth.uid());

CREATE POLICY "Authors can delete own posts" 
  ON posts FOR DELETE 
  USING (author_id = auth.uid());

-- Comments policies
CREATE POLICY "Comments on published posts are viewable by everyone" 
  ON comments FOR SELECT 
  USING (EXISTS (
    SELECT 1 FROM posts 
    WHERE posts.id = post_id 
    AND (posts.published = true OR posts.author_id = auth.uid())
  ));

CREATE POLICY "Authenticated users can create comments" 
  ON comments FOR INSERT 
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Users can update own comments" 
  ON comments FOR UPDATE 
  USING (author_id = auth.uid());

CREATE POLICY "Users can delete own comments" 
  ON comments FOR DELETE 
  USING (author_id = auth.uid());

-- Create indexes for better performance
CREATE INDEX posts_author_id_idx ON posts(author_id);
CREATE INDEX comments_post_id_idx ON comments(post_id);
CREATE INDEX comments_author_id_idx ON comments(author_id);

-- Create function to handle updated_at
CREATE OR REPLACE FUNCTION handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE PROCEDURE handle_updated_at();

CREATE TRIGGER posts_updated_at
  BEFORE UPDATE ON posts
  FOR EACH ROW
  EXECUTE PROCEDURE handle_updated_at();

CREATE TRIGGER comments_updated_at
  BEFORE UPDATE ON comments
  FOR EACH ROW
  EXECUTE PROCEDURE handle_updated_at();

-- Create admin policies
DO $$
BEGIN
  -- Posts admin policies
  CREATE POLICY "Admins can view all posts"
    ON posts FOR SELECT
    USING (EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'ADMIN'
    ));

  CREATE POLICY "Admins can update all posts"
    ON posts FOR UPDATE
    USING (EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'ADMIN'
    ));

  CREATE POLICY "Admins can delete all posts"
    ON posts FOR DELETE
    USING (EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'ADMIN'
    ));

  -- Comments admin policies
  CREATE POLICY "Admins can update all comments"
    ON comments FOR UPDATE
    USING (EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'ADMIN'
    ));

  CREATE POLICY "Admins can delete all comments"
    ON comments FOR DELETE
    USING (EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'ADMIN'
    ));
END $$;