#!/usr/bin/env python3

from __future__ import annotations

import typing
import sys
import os
from pathlib import Path
from ipaddress import IPv4Network, IPv6Network, AddressValueError
import ray_pb2


def load_networks(
    dat_files: typing.List[str], countries: typing.List[str], inverse: bool = False
) -> typing.List[IPv4Network | IPv6Network]:
    networks = []
    country_codes = [code.lower() for code in countries]
    for file in dat_files:
        file_path = Path(file).resolve()
        if not file_path.exists() or not file_path.is_file():
            continue
        data = ray_pb2.GeoIPList()
        with open(file_path, 'rb') as fp:
            data.ParseFromString(fp.read())
        for entry in data.entry:
            if inverse:
                if entry.country_code.lower() in country_codes:
                    continue
            else:
                if entry.country_code.lower() not in country_codes:
                    continue
            for cidr in entry.cidr:
                try:
                    networks.append(IPv4Network((cidr.ip, cidr.prefix)))
                except AddressValueError:
                    pass
                try:
                    networks.append(IPv6Network((cidr.ip, cidr.prefix)))
                except AddressValueError:
                    pass
    return networks


def load_domains(
    dat_files: typing.List[str],
    countries: typing.List[str],
    inverse: bool = False,
    domain_type: int | None = None,
) -> typing.List[str]:
    domains = []
    country_codes = [code.lower() for code in countries]
    for file in dat_files:
        file_path = Path(file).resolve()
        if not file_path.exists() or not file_path.is_file():
            continue
        data = ray_pb2.GeoSiteList()
        with open(file_path, 'rb') as fp:
            data.ParseFromString(fp.read())
        for entry in data.entry:
            if inverse:
                if entry.country_code.lower() in country_codes:
                    continue
            else:
                if entry.country_code.lower() not in country_codes:
                    continue
            for domain in entry.domain:
                value = None
                if domain_type is None:
                    value = domain.value
                elif domain.type == domain_type:
                    value = domain.value
                if value:
                    domains.append(domain.value)
    return domains


def main(args):
    input_files = getattr(args, 'input', None)
    output = getattr(args, 'output', None)

    data_list = []
    if getattr(args, 'data_type', None) == 'geoip':
        data_list = load_networks(
            input_files,
            getattr(args, 'countries', None),
            getattr(args, 'inverse', None),
        )
    if getattr(args, 'data_type', None) == 'geosite':
        data_list = load_domains(
            input_files,
            getattr(args, 'countries', None),
            getattr(args, 'inverse', None),
            getattr(args, 'domain_type', None),
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
        type=str,
        default=[],
        help='input ray data files (separated by space)',
    )
    parser.add_argument(
        '-c',
        '--countries',
        nargs='+',
        type=str,
        default=[],
        help='country codes (separated by space)',
    )
    parser.add_argument(
        '-i',
        '--inverse',
        action='store_true',
        help='inverse match country code',
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
        '--domain-type',
        type=int,
        help='geosite domain type',
    )

    args = parser.parse_args()
    args.func(args)
