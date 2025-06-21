// Helper function to parse JIRA API error responses
export const parseJiraAPIErrorResponse = (error, fallbackMessage) => {
  // Check if it's a structured error response
  if (error.response?.data?.error) {
    const errorData = error.response.data.error;
    
    // Handle JIRA-specific error formats
    if (typeof errorData === 'string') {
      return errorData;
    }
    
    // Handle JIRA error objects with errorMessages array
    if (errorData.errorMessages && Array.isArray(errorData.errorMessages)) {
      return errorData.errorMessages.join(', ');
    }
    
    // Handle JIRA error objects with errors object
    if (errorData.errors && typeof errorData.errors === 'object') {
      const errorMessages = Object.values(errorData.errors);
      if (errorMessages.length > 0) {
        return errorMessages.join(', ');
      }
    }
    
    // Handle generic error objects
    if (errorData.message) {
      return errorData.message;
    }
  }
  
  // Check for direct error message in response
  if (error.response?.data?.message) {
    return error.response.data.message;
  }
  
  // Check for HTTP status-based messages
  if (error.response?.status) {
    const status = error.response.status;
    if (status === 401) {
      return 'Authentication failed. Please check your JIRA credentials.';
    }
    if (status === 403) {
      return 'Access denied. Please check your JIRA permissions.';
    }
    if (status === 404) {
      return 'JIRA resource not found. Please check your configuration.';
    }
    if (status === 429) {
      return 'Rate limit exceeded. Please try again later.';
    }
    if (status >= 500) {
      return 'JIRA server error. Please try again later.';
    }
  }
  
  // Check for network errors
  if (error.code === 'NETWORK_ERROR' || !error.response) {
    return 'Network error. Please check your connection to JIRA.';
  }
  
  // Fall back to provided message or generic error
  return fallbackMessage || 'An unexpected error occurred while connecting to JIRA.';
};
