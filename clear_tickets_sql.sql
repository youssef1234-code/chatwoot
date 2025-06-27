-- Clear all tickets and JIRA links - SQL Script
-- Run in psql or Rails dbconsole

-- Count before cleanup
SELECT 
  (SELECT COUNT(*) FROM tickets) as tickets_count,
  (SELECT COUNT(*) FROM jira_issue_links) as jira_links_count;

-- Option A: Clear JIRA data from tickets but keep tickets
UPDATE tickets SET 
  jira_issue_key = NULL,
  jira_status = NULL,
  jira_in_progress = NULL;

DELETE FROM jira_issue_links;

-- Option B: Delete all tickets completely (uncomment if needed)
-- DELETE FROM ticket_messages;
-- DELETE FROM tickets;

-- Count after cleanup
SELECT 
  (SELECT COUNT(*) FROM tickets) as tickets_count,
  (SELECT COUNT(*) FROM jira_issue_links) as jira_links_count;
