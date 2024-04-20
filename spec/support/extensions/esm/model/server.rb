# frozen_string_literal: true

module ESM
  class Server
    #
    # Sends the provided SQF code to the linked connection.
    #
    # @param code [String] Valid and error free SQF code as a string
    #
    # @return [Any] The result of the SQF code.
    #
    # @note: The result is ran through a JSON parser during the communication process. The type may not be what you expect, but it will be consistent
    #
    def execute_sqf!(code, steam_uid: nil)
      message = ESM::Message.new.set_type(:arma)
        .set_data(:sqf, {execute_on: "server", code: code})
        .set_metadata(player: {steam_uid: steam_uid || ""})

      send_message(message)
    end
  end
end