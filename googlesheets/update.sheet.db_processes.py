#!/usr/bin/python 
import os.path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from datetime import datetime

import psycopg2


# If modifying these scopes, delete the file token.json.
SCOPES = ["https://www.googleapis.com/auth/drive"]
#SCOPES = ["https://www.googleapis.com/auth/spreadsheets.readonly"]

# The ID and randatabase infoge of a sample spreadsheet.
spreadsheet_id = "1IYf6DunrjY47oqp1uvlUj9Df2xdlbti_Bw-SBrQiPU0"

class PgToGs(object):
    def __init__(self):
        self._creds = None
        self._conn = None

    def __del__(self):
        if self._conn is not None:
            self._conn.close()

    @property
    def creds(self):
        if self._creds is None:
            self._creds = self._get_creds()

        return self._creds

    def _get_creds(self):
        creds = None
        # The file token.json stores the user's access and refresh tokens, and is
        # created automatically when the authorization flow completes for the first
        # time.
        if os.path.exists("token.json"):
            creds = Credentials.from_authorized_user_file("token.json", SCOPES)
        # If there are no (valid) credentials available, let the user log in.
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                flow = InstalledAppFlow.from_client_secrets_file(
                    "credentials.json", SCOPES
                )
                creds = flow.run_local_server(port=0)

        # Save the credentials for the next run
        with open("token.json", "w") as token:
            token.write(creds.to_json())

        return creds

    def batch_update_values(self,
            spreadsheet_id, range_name, value_input_option, _values
            ):
        """
        Creates the batch_update the user has access to.
        Load pre-authorized user credentials from the environment.
        TODO(developer) - See https://developers.google.com/identity
        for guides on implementing OAuth2 for the application.
        """
#  creds, _ = google.auth.default()
            # pylint: disable=maybe-no-member
        try:
            service = build("sheets", "v4", credentials=self.creds)

            values = [
                [
                    # Cell values ...
                ],
                # Additional rows
            ]
            # [START_EXCLUDE silent]
            values = _values
            # [END_EXCLUDE]
            data = [
                {"range": range_name, "values": values},
                # Additional ranges to update ...
            ]
            body = {"valueInputOption": value_input_option, "data": data}
            result = (
                    service.spreadsheets()
                    .values()
                    .batchUpdate(spreadsheetId=spreadsheet_id, body=body)
                    .execute()
            )
            print(f"{(result.get('totalUpdatedCells'))} cells updated.")
            return result
        except HttpError as error:
            print(f"An error occurred: {error}")
            return error

    @property
    def conn(self):
        if self._conn is None:
            self._conn = psycopg2.connect("dbname=postgres user=postgres host=127.0.0.1")

        return self._conn

    def db_fetch(self,sql):
        with self.conn.cursor() as cur:
            cur.execute(sql)
            print(cur.description)
            out = []
            h = []
            for el in cur.description:
                h.append(el.name)
            out.append(h)
            rs = cur.fetchall()
            for row in rs:
                r = []
                for el in row:
                    r.append(el)
                out.append(r)

            return out

def main():
  """Shows basic usage of the Sheets API.
  Prints values from a sample spreadsheet.
  """

  sheet = PgToGs()

  data = [
    ['linkedin people',''],
    ]

#  rs = sheet.db_fetch("with p as (select regexp_replace(page,'-.*','') as l, regexp_replace(page,'.*-','')::integer as n from pending_lip where resolved is not null) select max(l) as l,max(n)-1 as n from p where l = (select max(l) from p);")

  data.append(['',' current max page'])
  row = ['']
#  row.extend(rs[1])
  row.extend(['hard coded'])
  data.append(row)

#  rs = sheet.db_fetch("select count(*) as c from lipd;")
  row = ['']
  row.extend([5])

  data.append(['',' lipd record count'])
  data.append(row)

  now = datetime.now()
  row = ['',now.strftime("%Y-%m-%d %I:%M %p")]
  data.append(['',' updated'])
  data.append(row)

  print(data)
  sheet.batch_update_values(
          spreadsheet_id,
          'dB processes!A1:J',
          "USER_ENTERED",
          data
  )

if __name__ == "__main__":
  main()
