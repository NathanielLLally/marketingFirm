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
            self._conn = psycopg2.connect("dbname=postgres user=postgres host=mail.winblows98.com")

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
    ]

  sql = "select domain, TO_CHAR(created, 'YYYY-MM-DD HH24:MI:SS') as created, TO_CHAR(updated, 'YYYY-MM-DD HH24:MI:SS') as updated, contact1, name1,org1,email1,phone1, contact2, name2,org2,email2,phone2, contact3, name3,org3,email3,phone3 from wi.nfo join wi.vcnfo on nfo.id = vcnfo.nfoid join (select vc.id, 'tech' as contact3, name as name3, organization as org3, email as email3, phone as phone3 from wi.vc ) as vt on vt.id = nfo.tech join (select vc.id, 'admin' as contact2, name as name2, organization as org2, email as email2, phone as phone2      from wi.vc ) as va on va.id = nfo.admin join (select vc.id, 'registrant' as contact1, name as name1, organization as org1, email as email1, phone as phone1     from wi.vc ) as vr on vr.id = nfo.registrant "

  rs = sheet.db_fetch(f"select count(*) as record_count from ({sql})")
  ranges = 'dB2!A2:B'
  data = [[rs[0][0], rs[1][0]]]
  sheet.batch_update_values(
          spreadsheet_id,
          ranges,
          "USER_ENTERED",
          data
  )

  rs = sheet.db_fetch(f"select * from ({sql}) where random() < 0.01 limit 1000")
  ranges = 'dB2!A4:'
  a = ord('A')
  ranges += chr(a+ len(rs[0]) - 1).upper()
  print(ranges)
  print(rs[0])
  sheet.batch_update_values(
          spreadsheet_id,
          ranges,
          "USER_ENTERED",
          rs
  )

if __name__ == "__main__":
  main()
