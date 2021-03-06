import json

import boto.dynamodb2.exceptions

from db.db_base import JBoxDB


class JBoxSessionProps(JBoxDB):
    NAME = 'jbox_session'
    TABLE = None

    def __init__(self, session_id, create=False, user_id=None):
        if self.table() is None:
            return

        self.item = None
        try:
            self.item = self.table().get_item(session_id=session_id)
            self.is_new = False
        except boto.dynamodb2.exceptions.ItemNotFound:
            if create:
                data = {
                    'session_id': session_id
                }
                if user_id is not None:
                    data['user_id'] = user_id
                self.create(data)
                self.item = self.table().get_item(session_id=session_id)
                self.is_new = True
            else:
                raise

    def get_user_id(self):
        return self.get_attrib('user_id')

    def set_user_id(self, user_id):
        self.set_attrib('user_id', user_id)

    def get_snapshot_id(self):
        return self.get_attrib('snapshot_id')

    def set_snapshot_id(self, snapshot_id):
        self.set_attrib('snapshot_id', snapshot_id)

    def get_message(self):
        msg = self.get_attrib('message')
        if msg is not None:
            msg = json.loads(msg)
        return msg

    def set_message(self, message, delete_on_display=True):
        msg = {
            'msg': message,
            'del': delete_on_display
        }
        self.set_attrib('message', json.dumps(msg))