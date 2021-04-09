WITH board_subscription_threads AS (
  SELECT
    subscriptions.id AS subscription_id,
    subscriptions.name AS subscription_name,
    subscriptions.string_id AS subscription_string_id,
    -- TODO: this needs to be transformed into the UTC string
    (CASE WHEN GREATEST(last_post.update_time, last_comment.update_time) IS NULL 
     THEN NULL 
     ELSE TO_CHAR(GREATEST(last_post.update_time, last_comment.update_time), 'YYYY-MM-DD"T"HH24:MI:SS') END)  AS last_updated,
    thread_identities.secret_identity_name,
    thread_identities.secret_identity_avatar,
    thread_identities.secret_identity_color,
    thread_identities.accessory_avatar as secret_identity_accessory,
    top_posts."content" AS post_content,
    threads.string_id AS thread_string_id,
    NULL AS latest_post_string_id
  FROM subscriptions
    INNER JOIN board_category_subscriptions bcs ON bcs.subscription_id = subscriptions.id
    INNER JOIN board_category_mappings bcm ON bcs.board_category_mapping_id = bcm.id
    INNER JOIN threads ON threads.parent_board = bcm.board_id
    -- In boards, the top posts categories are what count as "threads categories"
    INNER JOIN posts AS top_posts ON top_posts.parent_thread = threads.id AND parent_post IS NULL
    INNER JOIN LATERAL (SELECT MAX(posts.created) AS update_time FROM posts WHERE posts.parent_thread = threads.id) AS last_post ON 1=1
    INNER JOIN LATERAL (SELECT MAX(comments.created) AS update_time FROM comments WHERE comments.parent_thread = threads.id) AS last_comment ON 1=1
    INNER JOIN post_categories ON top_posts.id = post_categories.post_id AND bcm.category_id = post_categories.category_id
    LEFT JOIN thread_identities ON threads.id = thread_identities.thread_id
  WHERE subscriptions.string_id = ${subscription_string_id}
    AND GREATEST(last_post.update_time, last_comment.update_time) <= COALESCE(${last_activity_cursor}, NOW())
  ORDER BY last_updated DESC
  LIMIT ${page_size} + 1 
),
thread_subscription_threads AS (
  SELECT
    subscriptions.id AS subscription_id,
    subscriptions.name AS subscription_name,
    subscriptions.string_id AS subscription_string_id,
  -- TODO: this should also consider the tree for the last update rather than just the post and its comments
    TO_CHAR(posts.created, 'YYYY-MM-DD"T"HH24:MI:SS') AS last_updated,
    thread_identities.secret_identity_name,
    thread_identities.secret_identity_avatar,
    thread_identities.secret_identity_color,
    thread_identities.accessory_avatar as secret_identity_accessory,
    posts."content" AS post_content,
    posts.string_id AS latest_post_string_id,
    threads.string_id AS thread_string_id
  FROM subscriptions
  INNER JOIN thread_category_subscriptions tcs ON tcs.subscription_id = subscriptions.id
  INNER JOIN threads ON threads.id = tcs.thread_id
  INNER JOIN posts ON posts.parent_thread = tcs.thread_id
  INNER JOIN post_categories ON posts.id = post_categories.post_id AND tcs.category_id = post_categories.category_id 
  LEFT JOIN thread_identities ON threads.id = thread_identities.thread_id
  WHERE subscriptions.string_id = ${subscription_string_id}
    AND posts.created <= COALESCE(${last_activity_cursor}, NOW())
  ORDER BY last_updated DESC 
  LIMIT ${page_size} + 1 
)
(SELECT * FROM thread_subscription_threads)
UNION
(SELECT * FROM board_subscription_threads)
ORDER BY last_updated
LIMIT ${page_size} + 1;
