from . import CloudDatastoreRunner, locate_command


BaseCommand = locate_command("runserver")


class Command(CloudDatastoreRunner, BaseCommand):
    pass
