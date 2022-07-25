import { NpmRegistryResponse, packageObject } from "./type";
import axios from "axios";
import { Octokit } from "@octokit/rest";
import { GetResponseDataTypeFromEndpointMethod, OctokitResponse, RequestError } from "@octokit/types"


const octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN,
});
type Content = OctokitResponse<GetResponseDataTypeFromEndpointMethod<typeof octokit.repos.getContent>, 200>
type ContentResponse = Promise<Content>

const get_repo_id_by_package_name = async (name: string): Promise<number> => {
  
  const repo_path = await axios.get(`https://registry.npmjs.org/${name}`).then(
    (res) => res.data
  ) as NpmRegistryResponse;

  const info = repo_path.repository.url.match(/https:\/\/github.com\/(.*?)\/(.*)/);

  const repo = await octokit.request("GET /repos/{owner}/{repo}", {
    owner: info![1],
    repo: (info![2].replace('.git', '')).split('/')[0]
  });

  return repo.data.id;
};

const get_file = async (id: number, file: string): Promise<ContentResponse> => {
  const repo = await octokit.request("GET /repositories/{id}", {
    id: id,
  });

  return await octokit.request("GET /repos/{owner}/{repo}/contents/{path}", {
    owner: repo.data.owner.login,
    repo: repo.data.name,
    path: file,
  });
};

export const getDependencies = async (id: number): Promise<number[]> => {
  const file = await get_file(id, 'package.json')
  const data = file.data;
  type keys = keyof typeof data;
  const package_obj = await axios.get(data['download_url' as keys], {
    method: "GET",
  }).then((res) => res.data) as packageObject;

  const list: number[] = [];

  if (package_obj.dependencies) {
    await getDependencyList(package_obj.dependencies, list)
  }

  return list;
};

export const getAddress = async (id: number): Promise<string> => {
  var file: Content;
  var address: string = "";
  try {
    file = await get_file(id, "address.pizza");
    const data = file!.data;
    type keys = keyof typeof data;
    const content = await axios.get(
      data['download_url' as keys], { method: "GET" }
    ).then((res) => res.data);
    address = content.trim();
  } catch (err: any) {
    if (err.status === 404) {
      address = "";
    }
  } finally {
    return address;
  }
}

const getDependencyList = async (dependencies: object, list: number[]) => {
  if (!dependencies || Object.keys(dependencies).length == 0) {
    return list;
  }

  for (const dependency in dependencies) {
    const id = await get_repo_id_by_package_name(dependency);
    list.push(id);
    const file = await get_file(id, 'package.json');
    const data = file.data;
    type keys = keyof typeof data;
    const package_obj = await axios.get(data['download_url' as keys], {
      method: "GET",
    }).then((res) => res.data) as packageObject;
    await getDependencyList(package_obj.dependencies, list);
  }
}
