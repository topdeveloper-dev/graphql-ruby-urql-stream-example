class GraphqlController < ApplicationController
  include ActionController::Live
  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  protect_from_forgery with: :null_session

  def execute
    response.headers['Last-Modified'] = Time.now.httpdate
    variables = prepare_variables(params[:variables])
    query = params[:query].gsub("initial_count", "initialCount")
    operation_name = params[:operationName]
    context = {
      # Query context goes here, for example:
      # current_user: current_user,
    }
    result = StreamServerSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    # Check if this is a deferred query:
    if (deferred = result.context[:defer])
      # Stream an urql-friendly response over ActionController::Live
      # like https://github.com/FormidableLabs/urql/blob/main/examples/with-defer-stream-directives/server/index.js
      response.headers["Content-Type"] = "multipart/mixed; boundary=\"-\""
      response.headers["Connection"] = "keep-alive"
      # urql expects a leading boundary marker:
      response.stream.write("---")
      deferred.deferrals.each_with_index do |deferral, idx|
        payload = {}
        payload["data"] = deferral.data
        if idx > 0
          payload["path"] = deferral.path
        end
        payload["hasNext"] = deferral.has_next?

        patch = [
          "",
          "Content-Type: application/json; charset=utf-8",
          "",
          JSON.dump(payload)
        ]
        patch << "---" if deferral.has_next?
        patch_str = patch.join("\r\n")

        sleep 0.1
        puts Time.now.to_f
        puts patch_str.inspect

        response.stream.write(patch_str)
      end

      response.stream.write("\r\n-----")
    else
      # Return a plain, non-deferred result
      render json: result
    end
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  ensure
    response.stream.close
  end

  private

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [{ message: e.message, backtrace: e.backtrace }], data: {} }, status: 500
  end
end
