# frozen_string_literal: true

class Api::V1::Integrations::Orchestrator::WebhooksController < ApplicationController
  skip_before_action :authenticate_user!, only: [:create]
  skip_before_action :set_current_user, only: [:create]
  before_action :verify_orchestrator_token, only: [:create]

  def index
    render json: { message: 'Orchestrator webhook endpoint is active' }
  end

  def create
    Rails.logger.info("Orchestrator Webhook: Received data: #{request.raw_post}")

    begin
      webhook_data = JSON.parse(request.raw_post)
      event_type = webhook_data['event']

      Rails.logger.info("Orchestrator Webhook: Event type: #{event_type}")

      case event_type
      when 'onboarding.phase_completed'
        handle_phase_completed(webhook_data)
      when 'onboarding.started'
        handle_onboarding_started(webhook_data)
      when 'onboarding.completed'
        handle_onboarding_completed(webhook_data)
      when 'invoice.issued'
        handle_invoice_issued(webhook_data)
      when 'invoice.paid'
        handle_invoice_paid(webhook_data)
      when 'contact.update'
        handle_contact_update(webhook_data)
      end

      render json: { status: 'success', message: 'Webhook processed successfully' }
    rescue JSON::ParserError => e
      Rails.logger.error("Orchestrator Webhook: Invalid JSON received: #{e.message}")
      render json: { error: 'Invalid JSON format' }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error("Orchestrator Webhook: Error processing webhook: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  private

  def verify_orchestrator_token
    orchestrator_token = ENV.fetch('ORCHESTRATOR_WEBHOOK_TOKEN', nil)
    return unless orchestrator_token.present?

    provided_token = request.headers['X-Orchestrator-Token']
    unless ActiveSupport::SecurityUtils.secure_compare(orchestrator_token, provided_token.to_s)
      Rails.logger.warn("Orchestrator Webhook: Invalid token")
      render json: { error: 'Invalid token' }, status: :unauthorized
    end
  end

  def handle_phase_completed(data)
    company_slug = data['company_slug']
    phase_name = data['phase_name']
    phase_number = data['phase_number']
    
    contact = find_contact_by_company_slug(company_slug)
    return unless contact

    # Update contact custom attributes
    contact.custom_attributes ||= {}
    contact.custom_attributes['onboarding_phase'] = phase_name
    contact.custom_attributes['onboarding_phase_number'] = phase_number
    contact.custom_attributes['onboarding_last_updated'] = Time.current.iso8601
    contact.save!

    Rails.logger.info("Orchestrator Webhook: Updated contact #{contact.id} with phase #{phase_name}")
  end

  def handle_onboarding_started(data)
    company_slug = data['company_slug']
    client_name = data['client_name']
    start_date = data['start_date']
    plane_epic_url = data['plane_epic_url']
    
    contact = find_contact_by_company_slug(company_slug)
    return unless contact

    contact.custom_attributes ||= {}
    contact.custom_attributes['onboarding_status'] = 'active'
    contact.custom_attributes['onboarding_start_date'] = start_date
    contact.custom_attributes['onboarding_phase'] = 'initialization'
    contact.custom_attributes['onboarding_phase_number'] = 0
    contact.custom_attributes['plane_epic_url'] = plane_epic_url if plane_epic_url
    contact.save!

    Rails.logger.info("Orchestrator Webhook: Started onboarding for contact #{contact.id}")
  end

  def handle_onboarding_completed(data)
    company_slug = data['company_slug']
    completion_date = data['completion_date']
    
    contact = find_contact_by_company_slug(company_slug)
    return unless contact

    contact.custom_attributes ||= {}
    contact.custom_attributes['onboarding_status'] = 'completed'
    contact.custom_attributes['onboarding_completion_date'] = completion_date
    contact.save!

    Rails.logger.info("Orchestrator Webhook: Completed onboarding for contact #{contact.id}")
  end

  def handle_invoice_issued(data)
    company_slug = data['company_slug']
    invoice_number = data['invoice_number']
    amount = data['amount']
    due_date = data['due_date']
    
    contact = find_contact_by_company_slug(company_slug)
    return unless contact

    contact.custom_attributes ||= {}
    contact.custom_attributes['last_invoice_number'] = invoice_number
    contact.custom_attributes['last_invoice_amount'] = amount
    contact.custom_attributes['last_invoice_due_date'] = due_date
    contact.custom_attributes['invoice_status'] = 'pending'
    contact.save!

    Rails.logger.info("Orchestrator Webhook: Updated invoice info for contact #{contact.id}")
  end

  def handle_invoice_paid(data)
    company_slug = data['company_slug']
    invoice_number = data['invoice_number']
    payment_date = data['payment_date']
    
    contact = find_contact_by_company_slug(company_slug)
    return unless contact

    contact.custom_attributes ||= {}
    contact.custom_attributes['invoice_status'] = 'paid'
    contact.custom_attributes['last_payment_date'] = payment_date
    contact.save!

    Rails.logger.info("Orchestrator Webhook: Updated payment info for contact #{contact.id}")
  end

  def handle_contact_update(data)
    company_slug = data['company_slug']
    attributes = data['attributes'] || {}
    
    contact = find_contact_by_company_slug(company_slug)
    return unless contact

    contact.custom_attributes ||= {}
    contact.custom_attributes.merge!(attributes)
    contact.save!

    Rails.logger.info("Orchestrator Webhook: Updated custom attributes for contact #{contact.id}")
  end

  def find_contact_by_company_slug(company_slug)
    # Find contact by company_slug custom attribute
    Contact.where("custom_attributes->>'company_slug' = ?", company_slug).first ||
      Contact.where("custom_attributes->>'company' = ?", company_slug).first ||
      Contact.where("custom_attributes->>'identifier' = ?", company_slug).first
  end
end
