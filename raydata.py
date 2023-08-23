#!/usr/bin/env python3

from __future__ import annotations

import typing
import sys
import os
import json
from pathlib import Path
from ipaddress import IPv4Network, IPv6Network, AddressValueError
import ray_pb2


def load_formatter(formatter: Path | None) -> dict | None:
    try:
        format_file_path = formatter.resolve()
        with format_file_path.open(encoding='utf-8') as fp:
            return json.load(fp)
    except (AttributeError, OSError, json.JSONDecodeError, TypeError):
        pass
    return None


def init_protobuf(data_type: str = None) -> tuple:
    if data_type == 'geoip':
        return (ray_pb2.GeoIPList(), 'cidr')
    if data_type == 'geosite':
        return (ray_pb2.GeoSiteList(), 'domain')
    return (None, None)


def load_resource(
    *,
    dat_files: typing.List[Path],
    countries: typing.List[str],
    inverse: bool = False,
    data_type: str | None = None,
    brief_search: str | None = None,
    domain_types: typing.List[int] | None = None,
    formatter: Path | None = None,
) -> list:
    resources = []
    country_codes = [code.lower() for code in countries]
    format_dict = load_formatter(formatter)
    for file in dat_files:
        file_path = file.resolve()
        if not file_path.exists() or not file_path.is_file():
            continue
        data_collection, list_name = init_protobuf(data_type)
        if not data_collection:
            return resources
        with open(file_path, 'rb') as fp:
            data_collection.ParseFromString(fp.read())
        for entry in data_collection.entry:
            if len(country_codes) > 0:
                if inverse:
                    if entry.country_code.lower() in country_codes:
                        continue
                else:
                    if entry.country_code.lower() not in country_codes:
                        continue
            if brief_search is not None:
                if brief_search:
                    if inverse:
                        if brief_search.lower() in entry.country_code.lower():
                            continue
                    else:
                        if brief_search.lower() not in entry.country_code.lower():
                            continue
                print(
                    f"{entry.country_code}: {sum(map(lambda record: not domain_types or record.type in domain_types, getattr(entry, list_name, None)))}"
                )
                continue
            for record in getattr(entry, list_name, None):
                if list_name == 'cidr':
                    try:
                        resources.append(IPv4Network((record.ip, record.prefix)))
                    except AddressValueError:
                        pass
                    try:
                        resources.append(IPv6Network((record.ip, record.prefix)))
                    except AddressValueError:
                        pass
                if list_name == 'domain':
                    if domain_types and record.type not in domain_types:
                        continue
                    prefix = ''
                    suffix = ''
                    if format_dict:
                        prefix = format_dict.get('prefix').get(str(record.type))
                        suffix = format_dict.get('suffix').get(str(record.type))
                    if record.value:
                        resources.append(f'{prefix}{record.value}{suffix}')
    return resources


def main(args):
    input_files = getattr(args, 'input', [])
    output = getattr(args, 'output', None)

    if (search := getattr(args, 'brief', None)) is not None:
        load_resource(
            dat_files=input_files,
            countries=getattr(args, 'country', []),
            inverse=getattr(args, 'inverse', False),
            data_type=getattr(args, 'data_type', None),
            domain_types=getattr(args, 'domain_types', None),
            brief_search=search,
        )
        sys.exit(0)

    data_list = load_resource(
        dat_files=input_files,
        countries=getattr(args, 'country', []),
        inverse=getattr(args, 'inverse', False),
        data_type=getattr(args, 'data_type', None),
        formatter=getattr(args, 'formatter', None),
        domain_types=getattr(args, 'domain_types', None),
    )
    if len(data_list) == 0:
        print('No legal data.')
        sys.exit(1)
    output_lines = [
        f"{getattr(args,'prefix','')}{str(entry)}{getattr(args,'suffix','')}"
        for entry in data_list
    ]
    if output is None:
        for line in output_lines:
            print(line, end='')
    else:
        output: Path
        output_file = output.resolve()
        if not output_file.parent.exists():
            os.makedirs(output_file.parent)
        if output_file.is_dir():
            print('Can not write to directory.')
        if output_file.exists():
            with output_file.open('a', encoding='utf-8') as wfp:
                wfp.writelines(output_lines)
        else:
            with output_file.open('w', encoding='utf-8') as wfp:
                wfp.writelines(output_lines)
        print(f'Output: {len(output_lines)}')


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        'input',
        nargs='+',
        type=Path,
        default=[],
        help='input ray data files (separated by space)',
    )
    parser.add_argument(
        '-c',
        '--country',
        type=str,
        action='append',
        default=[],
        help='country codes (use multiple times)',
    )
    parser.add_argument(
        '-i',
        '--inverse',
        action='store_true',
        help='inverse match country code',
    )
    parser.add_argument(
        '-b',
        '--brief',
        type=str,
        const='',
        nargs='?',
        help='show brief info about specified keyword',
    )
    parser.add_argument('-o', '--output', type=Path, help='output file to write')
    parser.add_argument(
        '-p', '--prefix', type=str, default='', help='write line prefix'
    )
    parser.add_argument(
        '-s', '--suffix', type=str, default='\n', help='write line suffix'
    )
    parser.set_defaults(func=main)

    subparser = parser.add_subparsers(dest='data_type', required=True)

    parser_geoip = subparser.add_parser(
        'geoip',
        help='use geoip as input',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    parser_geosite = subparser.add_parser(
        'geosite',
        help='use geosite as input',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser_geosite.add_argument(
        '--domain-types',
        nargs='+',
        type=int,
        help='select domain types (separated by space)',
    )
    parser_geosite.add_argument(
        '--formatter',
        type=Path,
        help='json formatter file base on domain types',
    )

    args = parser.parse_args()
    args.func(args)
