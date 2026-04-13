/**
 * Parse Plane API error responses and return a user-friendly message
 * @param {Error} error - The error object from the API call
 * @param {String} defaultMessage - Default message if parsing fails
 * @returns {String} - User-friendly error message
 */
export const parsePlaneAPIErrorResponse = (error, defaultMessage) => {
  if (!error) return defaultMessage;

  // Handle axios error responses
  if (error.response) {
    const { data, status } = error.response;

    // Handle specific HTTP status codes
    switch (status) {
      case 401:
        return 'Authentication failed. Please check your Plane API key.';
      case 403:
        return 'Access denied. You do not have permission to perform this action.';
      case 404:
        return 'Resource not found. The project or issue may have been deleted.';
      case 422:
        return data?.error || data?.message || 'Invalid request. Please check your input.';
      case 429:
        return 'Too many requests. Please wait and try again.';
      case 500:
        return 'Plane server error. Please try again later.';
      default:
        break;
    }

    // Try to extract error message from response data
    if (data) {
      if (typeof data === 'string') return data;
      if (data.error) return data.error;
      if (data.message) return data.message;
      if (data.detail) return data.detail;
      if (data.errors && Array.isArray(data.errors)) {
        return data.errors.join(', ');
      }
    }
  }

  // Handle network errors
  if (error.message === 'Network Error') {
    return 'Network error. Please check your connection.';
  }

  // Handle timeout errors
  if (error.code === 'ECONNABORTED') {
    return 'Request timed out. Please try again.';
  }

  return error.message || defaultMessage;
};

/**
 * Get status color based on Plane issue state
 * @param {String} state - The issue state/status
 * @returns {String} - Color hex code
 */
export const getStateColor = (state) => {
  const stateColors = {
    'backlog': '#6B7280',
    'unstarted': '#9CA3AF',
    'todo': '#64748b',
    'to_do': '#64748b',
    'started': '#3B82F6',
    'in_progress': '#8B5CF6',
    'in_review': '#D97706',
    'review': '#D97706',
    'done': '#10B981',
    'completed': '#10B981',
    'cancelled': '#EF4444',
    'blocked': '#DC2626',
  };
  
  const normalizedState = state?.toLowerCase().replace(/\s+/g, '_');
  return stateColors[normalizedState] || '#6B7280';
};

/**
 * Get priority label and color
 * @param {String} priority - The priority value
 * @returns {Object} - Priority label and color
 */
export const getPriorityInfo = (priority) => {
  const priorities = {
    'urgent': { label: 'Urgent', color: '#EF4444' },
    'high': { label: 'High', color: '#F59E0B' },
    'medium': { label: 'Medium', color: '#3B82F6' },
    'low': { label: 'Low', color: '#10B981' },
    'none': { label: 'None', color: '#6B7280' },
  };
  
  const normalizedPriority = priority?.toLowerCase();
  return priorities[normalizedPriority] || priorities.none;
};
