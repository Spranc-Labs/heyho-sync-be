# frozen_string_literal: true

module DataProcessing
  class DataSanitizationService
  # Constants for tracking parameters to remove
  TRACKING_PARAMS = %w[
    utm_source utm_medium utm_campaign utm_term utm_content
    fbclid gclid msclkid mc_eid _ga
  ].freeze

  def self.sanitize_page_visit(data)
    new.sanitize_page_visit(data)
  end

  def self.sanitize_tab_aggregate(data)
    new.sanitize_tab_aggregate(data)
  end

  # rubocop:disable Metrics/AbcSize
  # This method intentionally sanitizes multiple fields comprehensively
  def sanitize_page_visit(data)
    sanitized = data.dup

    sanitized['url'] = sanitize_url(sanitized['url']) if sanitized['url']
    if sanitized['title']
      sanitized['title'] =
        sanitize_text(sanitized['title'], DataValidationService::MAX_TITLE_LENGTH)
    end
    sanitized['domain'] = sanitize_domain(sanitized['domain']) if sanitized['domain']
    sanitized['duration_seconds'] = sanitize_duration(sanitized['duration_seconds']) if sanitized['duration_seconds']
    if sanitized['active_duration_seconds']
      sanitized['active_duration_seconds'] =
        sanitize_duration(sanitized['active_duration_seconds'])
    end
    if sanitized['scroll_depth_percent']
      sanitized['scroll_depth_percent'] =
        sanitize_scroll_depth(sanitized['scroll_depth_percent'])
    end
    if sanitized['engagement_rate']
      sanitized['engagement_rate'] =
        sanitize_engagement_rate(sanitized['engagement_rate'])
    end

    sanitized
  end
  # rubocop:enable Metrics/AbcSize

  # This method intentionally sanitizes multiple fields comprehensively
  def sanitize_tab_aggregate(data)
    sanitized = data.dup

    sanitized['url'] = sanitize_url(sanitized['url']) if sanitized['url']
    if sanitized['title']
      sanitized['title'] =
        sanitize_text(sanitized['title'], DataValidationService::MAX_TITLE_LENGTH)
    end
    sanitized['domain'] = sanitize_domain(sanitized['domain']) if sanitized['domain']
    sanitized['duration_seconds'] = sanitize_duration(sanitized['duration_seconds']) if sanitized['duration_seconds']
    if sanitized['active_duration_seconds']
      sanitized['active_duration_seconds'] =
        sanitize_duration(sanitized['active_duration_seconds'])
    end
    if sanitized['scroll_depth_percent']
      sanitized['scroll_depth_percent'] =
        sanitize_scroll_depth(sanitized['scroll_depth_percent'])
    end

    sanitized
  end

  private

  def sanitize_url(url)
    return url if url.blank?

    # Truncate if too long
    url = url[0...DataValidationService::MAX_URL_LENGTH] if url.length > DataValidationService::MAX_URL_LENGTH

    # Remove tracking parameters
    begin
      uri = URI.parse(url)
      if uri.query
        params = URI.decode_www_form(uri.query)
        cleaned_params = params.reject { |key, _| TRACKING_PARAMS.include?(key.downcase) }
        uri.query = cleaned_params.empty? ? nil : URI.encode_www_form(cleaned_params)
      end
      uri.to_s
    rescue URI::InvalidURIError
      # Return original if parsing fails
      url
    end
  end

  def sanitize_text(text, max_length)
    return text if text.blank?

    # Strip whitespace
    cleaned = text.strip

    # Remove control characters
    cleaned = cleaned.gsub(/[[:cntrl:]]/, '')

    # Truncate if too long
    cleaned = cleaned[0...max_length] if cleaned.length > max_length

    cleaned
  end

  def sanitize_domain(domain)
    return domain if domain.blank?

    # Normalize to lowercase
    cleaned = domain.downcase.strip

    # Remove www prefix
    cleaned = cleaned.sub(/^www\./, '')

    # Truncate if too long
    if cleaned.length > DataValidationService::MAX_DOMAIN_LENGTH
      cleaned = cleaned[0...DataValidationService::MAX_DOMAIN_LENGTH]
    end

    cleaned
  end

  def sanitize_duration(duration)
    return duration if duration.blank?

    # Convert to numeric if string
    duration = duration.to_f if duration.is_a?(String)

    # Clamp to valid range
    duration = [duration, 0].max
    duration = [duration, DataValidationService::MAX_DURATION].min

    # Round to 2 decimal places
    duration.round(2)
  end

  def sanitize_scroll_depth(depth)
    return depth if depth.blank?

    # Convert to numeric if string
    depth = depth.to_f if depth.is_a?(String)

    # Clamp to valid range (0-100)
    depth = depth.clamp(DataValidationService::MIN_SCROLL_DEPTH, DataValidationService::MAX_SCROLL_DEPTH)

    # Round to 2 decimal places
    depth.round(2)
  end

  def sanitize_engagement_rate(rate)
    return rate if rate.blank?

    # Convert to numeric if string
    rate = rate.to_f if rate.is_a?(String)

    # Clamp to valid range (0.0-1.0)
    rate = rate.clamp(DataValidationService::MIN_ENGAGEMENT_RATE, DataValidationService::MAX_ENGAGEMENT_RATE)

    # Round to 4 decimal places
    rate.round(4)
  end
  end
end
